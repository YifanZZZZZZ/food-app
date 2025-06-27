from flask import Blueprint, request, jsonify
from pymongo import MongoClient
import hashlib
import os
import traceback
from bson.objectid import ObjectId

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


# -----------------------------
# Login Endpoint (with debug logs)
# -----------------------------
@auth_bp.route('/login', methods=['POST'])
def login():
    try:
        data = request.json
        email = data.get("email")
        password = data.get("password")

        print(f"🔐 LOGIN ATTEMPT: {email}")

        if not email or not password:
            print("❌ Missing email or password in request")
            return jsonify({"error": "Missing credentials"}), 400

        hashed_pw = hashlib.sha256(password.encode()).hexdigest()
        print(f"🔑 Hashed Password: {hashed_pw}")

        user = users_collection.find_one({"email": email, "password": hashed_pw})
        print(f"✅ User found: {bool(user)}")

        if not user:
            print("❌ Invalid credentials")
            return jsonify({"error": "Invalid credentials"}), 401

        response = {"user_id": str(user["_id"]), "name": user["name"]}
        print(f"🎯 Login Success: {response}")
        return jsonify(response)

    except Exception as e:
        print("❌ Exception in login:")
        traceback.print_exc()
        return jsonify({"error": "Server error", "details": str(e)}), 500


# -----------------------------
# Save Profile
# -----------------------------
@auth_bp.route('/save-profile', methods=['POST'])
def save_profile():
    try:
        data = request.json
        user_id = data.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id"}), 400

        profile = {k: v for k, v in data.items() if k != "user_id"}

        profiles_collection.update_one(
            {"user_id": user_id},
            {"$set": profile},
            upsert=True
        )
        print(f"✅ Profile saved for user: {user_id}")
        return jsonify({"message": "Profile saved"})
    except Exception as e:
        print("❌ Failed to save profile:")
        traceback.print_exc()
        return jsonify({"error": "Server error"}), 500


# -----------------------------
# Get Profile
# -----------------------------
@auth_bp.route('/profile', methods=['GET'])
def get_profile():
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"error": "Missing user_id"}), 400

    profile = profiles_collection.find_one({"user_id": user_id}, {"_id": 0})
    if not profile:
        return jsonify({"error": "Profile not found"}), 404

    return jsonify(profile)
