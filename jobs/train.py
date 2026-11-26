"""EN: Manual CPU training and TOS model round-trip. 中文：手工运行的 CPU 训练与模型回读验收。"""
import argparse
import csv
import io
import json
import math
import re


def fit(rows):
    """EN: Fit y = slope*x + intercept. 中文：最小二乘拟合直线。"""
    points = [(float(row["x"]), float(row["y"])) for row in rows]
    if len(points) < 2 or not all(math.isfinite(v) for p in points for v in p):
        raise ValueError("At least two finite samples are required")
    mean_x = sum(x for x, _ in points) / len(points)
    mean_y = sum(y for _, y in points) / len(points)
    variance = sum((x - mean_x) ** 2 for x, _ in points)
    if variance == 0:
        raise ValueError("Training x values must vary")
    slope = sum((x - mean_x) * (y - mean_y) for x, y in points) / variance
    intercept = mean_y - slope * mean_x
    mse = sum((slope * x + intercept - y) ** 2 for x, y in points) / len(points)
    return {"slope": slope, "intercept": intercept, "mse": mse, "samples": len(points)}


def main():
    import tos

    parser = argparse.ArgumentParser()
    for field in ["region", "endpoint", "role-name", "training-bucket", "models-bucket", "run-id"]:
        parser.add_argument("--" + field, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9_]{2,40}", args.run_id):
        parser.error("run-id must match [a-z][a-z0-9_]{2,40}")
    if not args.endpoint.startswith("https://"):
        parser.error("HTTPS endpoint required")
    client = tos.TosClientV2(
        endpoint=args.endpoint, region=args.region,
        credentials_provider=tos.EcsCredentialsProvider(args.role_name),
        enable_verify_ssl=True, enable_crc=True,
    )
    key = f"models/{args.run_id}/linear.json"
    # EN: Reusing a run ID is an error; do not run concurrent writers under one ID.
    # 中文：禁止复用运行标识，同一标识下不得并发写入。
    try:
        client.head_object(args.models_bucket, key)
    except tos.exceptions.TosServerError as exc:
        if exc.status_code != 404:
            raise RuntimeError(f"Model lookup failed with HTTP {exc.status_code}") from None
    else:
        raise RuntimeError("Model already exists; choose a new run ID")
    body = client.get_object(args.training_bucket, "datasets/linear.csv").read().decode("utf-8")
    model = fit(csv.DictReader(io.StringIO(body)))
    if not (math.isclose(model["slope"], 2) and math.isclose(model["intercept"], 1) and model["mse"] < 1e-12):
        raise AssertionError("Fit differs from the supplied public fixture")
    client.put_object(args.models_bucket, key, content=json.dumps(model).encode("utf-8"))
    loaded = json.loads(client.get_object(args.models_bucket, key).read())
    prediction = loaded["slope"] * 4 + loaded["intercept"]
    if loaded != model or not math.isclose(prediction, 9):
        raise AssertionError("Persisted model or inference mismatch")
    print(json.dumps({"status": "PASS", "model": loaded, "input": 4, "prediction": prediction}))


if __name__ == "__main__":
    main()
