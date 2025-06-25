from flask import Blueprint, request, jsonify, session
from pymongo import MongoClient
import hashlib
from bson.objectid import ObjectId
import os

auth_bp = Blueprint('auth', __name__)
client = MongoClient(os.getenv("MONGO_URI"))
db = client[os.getenv("MONGO_DB", "food-app-swift")]
users_collection = db["users"]
profiles_collection = db["profiles"]

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.json
    name, email, password = data.get("name"), data.get("email"), data.get("password")
    if not name or not email or not password:
        return jsonify({"error": "All fields required"}), 400
    if users_collection.find_one({"email": email}):
        return jsonify({"error": "Email exists"}), 409
    hashed_pw = hashlib.sha256(password.encode()).hexdigest()
    result = users_collection.insert_one({"name": name, "email": email, "password": hashed_pw})
    return jsonify({"user_id": str(result.inserted_id), "name": name})

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.json
    email, password = data.get("email"), data.get("password")
    if not email or not password:
        return jsonify({"error": "Missing credentials"}), 400
    hashed_pw = hashlib.sha256(password.encode()).hexdigest()
    user = users_collection.find_one({"email": email, "password": hashed_pw})
    if not user:
        return jsonify({"error": "Invalid credentials"}), 401
    return jsonify({"user_id": str(user["_id"]), "name": user["name"]})

@auth_bp.route('/save-profile', methods=['POST'])
def save_profile():
    data = request.json
    user_id = data.get("user_id")
    profile = {k: v for k, v in data.items() if k != "user_id"}
    profiles_collection.update_one(
        {"user_id": user_id},
        {"$set": profile},
        upsert=True
    )
    return jsonify({"message": "Profile saved"})
