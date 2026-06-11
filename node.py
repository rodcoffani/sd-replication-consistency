import os
import threading
import requests

from flask import Flask, jsonify, request

app = Flask(__name__)

counter = 0
version = 0
lock = threading.Lock()
peers = os.environ.get("PEERS", "").split(",") if os.environ.get("PEERS") else []
hostname = os.environ.get("HOSTNAME", "unknown")


def replicate():
    with lock:
        data = {"counter": counter, "version": version}

    for peer in peers:
        peer = peer.strip()
        if not peer:
            continue
        try:
            requests.post(f"{peer}/replicate", json=data, timeout=5)
        except requests.RequestException:
            pass


@app.route("/increment", methods=["POST"])
def increment():
    with lock:
        global counter, version
        counter += 1
        version += 1

    timer = threading.Timer(9.0, replicate)
    timer.daemon = True
    timer.start()

    return jsonify({"counter": counter, "version": version, "node": hostname}), 200


@app.route("/value", methods=["GET"])
def get_value():
    consistency = request.args.get("consistency", "")

    with lock:
        local = {"counter": counter, "version": version, "node": hostname}

    if consistency != "strong":
        return jsonify(local), 200

    best = local
    for peer in peers:
        peer = peer.strip()
        if not peer:
            continue
        try:
            resp = requests.get(f"{peer}/value", timeout=3)
            if resp.ok:
                data = resp.json()
                if data["version"] > best["version"]:
                    best = data
        except requests.RequestException:
            pass

    return jsonify(best), 200


@app.route("/replicate", methods=["POST"])
def receive_replication():
    data = request.get_json(force=True)
    received_counter = data.get("counter", 0)
    received_version = data.get("version", 0)

    with lock:
        global counter, version
        if received_version > version:
            counter = received_counter
            version = received_version

    return jsonify({"status": "ok"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
