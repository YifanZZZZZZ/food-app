# auth.py
from flask import Blueprint, request, jsonify
from pymongo import MongoClient
from bson.objectid import ObjectId
from dotenv import load_dotenv
import hashlib
import os
import traceback

load_dotenv()
auth_bp = Blueprint('auth', __name__)

# Connect to MongoDB
client = MongoClient(os.getenv("MONGO_URI"))
db = client[os.getenv("MONGO_DB", "food-app-swift")]
users_collection = db["users"]
profiles_collection = db["profiles"]

# -----------------------------
# Register Endpoint
# -----------------------------
@auth_bp.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
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

        return jsonify({"user_id": str(result.inserted_id), "name": name}), 200
    except Exception as e:
        print("❌ Register Exception:", str(e))
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# -----------------------------
# Login Endpoint
# -----------------------------
@auth_bp.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        email = data.get("email")
        password = data.get("password")

        if not email or not password:
            return jsonify({"error": "Missing credentials"}), 400

        hashed_pw = hashlib.sha256(password.encode()).hexdigest()
        user = users_collection.find_one({"email": email, "password": hashed_pw})

        if not user:
            return jsonify({"error": "Invalid credentials"}), 401

        return jsonify({"user_id": str(user["_id"]), "name": user["name"]}), 200
    except Exception as e:
        print("❌ Login Exception:", str(e))
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# -----------------------------
# Save Profile
# -----------------------------
@auth_bp.route('/save-profile', methods=['POST'])
def save_profile():
    try:
        data = request.get_json()
        user_id = data.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id"}), 400

        profile = {k: v for k, v in data.items() if k != "user_id"}

        profiles_collection.update_one(
            {"user_id": user_id},
            {"$set": profile},
            upsert=True
        )
        return jsonify({"message": "Profile saved"}), 200
    except Exception as e:
        print("❌ Profile Save Exception:", str(e))
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# -----------------------------
# Get Profile
# -----------------------------
@auth_bp.route('/profile', methods=['GET'])
def get_profile():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id"}), 400

        profile = profiles_collection.find_one({"user_id": user_id}, {"_id": 0})
        if not profile:
            return jsonify({"error": "Profile not found"}), 404

        return jsonify(profile), 200
    except Exception as e:
        print("❌ Get Profile Exception:", str(e))
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
