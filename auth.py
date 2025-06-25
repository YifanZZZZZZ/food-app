from flask import Blueprint, request, jsonify, session
from pymongo import MongoClient
import hashlib
from bson.objectid import ObjectId

auth_bp = Blueprint('auth', __name__)
client = MongoClient(os.getenv("MONGO_URI"))
db = client[os.getenv("MONGO_DB", "food_db")]
users_collection = db["users"]


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
    return jsonify({"message": "User registered", "user_id": str(result.inserted_id)})

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.json
    email, password = data.get("email"), data.get("password")
    user = users_collection.find_one({"email": email})
    if not user:
        return jsonify({"error": "User not found"}), 404
    if user["password"] != hashlib.sha256(password.encode()).hexdigest():
        return jsonify({"error": "Incorrect password"}), 401
    return jsonify({"message": "Login success", "user_id": str(user["_id"]), "name": user["name"]})
