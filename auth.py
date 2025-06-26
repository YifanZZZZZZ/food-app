from flask import Blueprint, request, jsonify
from pymongo import MongoClient
import hashlib
import os
import traceback

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
        return jsonify({"error": "Email already exists"}), 409

    hashed_pw = hashlib.sha256(password.encode()).hexdigest()
    result = users_collection.insert_one({
        "name": name,
        "email": email,
        "password": hashed_pw
    })

    return jsonify({"user_id": str(result.inserted_id), "name": name})


@auth_bp.route('/login', methods=['POST'])
def login():
    try:
        data = request.json
        email, password = data.get("email"), data.get("password")
        print(f"Login attempt for: {email}")

        if not email or not password:
            return jsonify({"error": "Missing credentials"}), 400

        hashed_pw = hashlib.sha256(password.encode()).hexdigest()
        print(f"Hashed password: {hashed_pw}")

        user = users_collection.find_one({"email": email, "password": hashed_pw})
        print("User found:", user is not None)

        if not user:
            return jsonify({"error": "Invalid credentials"}), 401

        return jsonify({"user_id": str(user["_id"]), "name": user["name"]})

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Server error: {str(e)}"}), 500
