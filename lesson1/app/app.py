import os
from flask import Flask, jsonify, request
from pymongo import MongoClient

app = Flask(__name__)
users = MongoClient(os.environ.get("MONGO_URI", "mongodb://localhost:27017/cnf")).get_default_database().users

@app.post("/signup")
def signup():
    data = request.get_json()
    if users.find_one({"username": data["username"]}):
        return jsonify(error="utente esistente"), 409
    users.insert_one({"username": data["username"], "password": data["password"]})
    return jsonify(username=data["username"]), 201

@app.post("/login")
def login():
    data = request.get_json()
    if users.find_one({"username": data["username"], "password": data["password"]}):
        return jsonify(ok=True)
    return jsonify(error="credenziali errate"), 401

@app.get("/health")
def health():
    return "ok\n"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
