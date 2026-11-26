"""EN: Manually submitted Spark acceptance job. 中文：显式提交的 Spark 验收作业。"""
import argparse
import re


def main():
    from pyspark.sql import SparkSession, functions as F

    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-bucket", required=True)
    parser.add_argument("--analysis-bucket", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--fail-before-write", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,40}", args.run_id):
        parser.error("run-id must match [a-z][a-z0-9_]{2,40}")
    for bucket in [args.raw_bucket, args.analysis_bucket]:
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,61}[a-z0-9]", bucket):
            parser.error("invalid bucket name")
    spark = SparkSession.builder.appName("data-lake-acceptance").enableHiveSupport().getOrCreate()
    try:
        raw = f"tos://{args.raw_bucket}/input"
        output = f"tos://{args.analysis_bucket}/results/{args.run_id}/wordcount"
        words = spark.read.text(f"{raw}/words.txt").select(
            F.explode(F.split(F.lower(F.col("value")), r"\s+")).alias("word")
        ).filter(F.col("word") != "").groupBy("word").count()
        expected = {"cloud": 2, "lake": 2, "spark": 1}
        if {r.word: r["count"] for r in words.collect()} != expected:
            raise AssertionError("Input counts differ from the supplied public fixture")
        if args.fail_before_write:
            raise RuntimeError("Intentional recoverable failure before output commit")
        # EN: A new run ID preserves earlier results. 中文：新运行标识保留历史结果。
        words.write.mode("errorifexists").json(output)
        observed = {r.word: r["count"] for r in spark.read.json(output).collect()}
        if observed != expected:
            raise AssertionError(f"Persisted result mismatch: {observed}")

        database = "lake_acceptance"
        table = f"{database}.sales_{args.run_id}"
        spark.sql(f"CREATE DATABASE IF NOT EXISTS {database}")
        spark.sql(f"""
            CREATE EXTERNAL TABLE {table} (id INT, category STRING, amount INT)
            PARTITIONED BY (dt STRING)
            ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
            STORED AS TEXTFILE LOCATION '{raw}/sales/'
        """)
        for day in ["2026-01-01", "2026-01-02"]:
            spark.sql(f"ALTER TABLE {table} ADD PARTITION (dt='{day}') LOCATION '{raw}/sales/dt={day}/'")
        frame = spark.table(table)
        expected_schema = [("id", "int"), ("category", "string"), ("amount", "int"), ("dt", "string")]
        if frame.dtypes != expected_schema:
            raise AssertionError(f"Schema mismatch: {frame.dtypes}")
        totals = {r.category: r.total for r in frame.groupBy("category").agg(F.sum("amount").alias("total")).collect()}
        partitions = {r.dt: r["count"] for r in frame.groupBy("dt").count().collect()}
        if totals != {"a": 40, "b": 60} or partitions != {"2026-01-01": 2, "2026-01-02": 2} or frame.count() != 4:
            raise AssertionError("Partition, record count or aggregate mismatch")
        detail = spark.sql(f"DESCRIBE FORMATTED {table}").collect()
        location = next(r.data_type for r in detail if r.col_name.strip() == "Location")
        if location.rstrip("/") != f"{raw}/sales":
            raise AssertionError("Catalog location differs from TOS path")
        print(f"PASS wordcount={observed}; rows=4; totals={totals}; partitions={partitions}; table={table}")
    finally:
        spark.stop()


if __name__ == "__main__":
    main()
