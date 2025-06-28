from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
from model_pipeline import full_image_analysis
import base64
import os
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# MongoDB connection
client = MongoClient(os.environ.get("MONGODB_URI"))
db = client["food_app"]
meals_collection = db["meals"]
users_collection = db["users"]
profiles_collection = db["profiles"]

@app.route("/")
def home():
    return "Food Analyzer Backend is Running"

# -------------------------------
# 🔐 Auth: Register/Login
# -------------------------------

@app.route("/register", methods=["POST"])
def register():
    data = request.get_json()
    if users_collection.find_one({"email": data["email"]}):
        return jsonify({"error": "Email already registered"}), 400

    user = {
        "name": data["name"],
        "email": data["email"],
        "password": data["password"]
    }
    result = users_collection.insert_one(user)
    return jsonify({"user_id": str(result.inserted_id), "name": data["name"]})

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    user = users_collection.find_one({"email": data["email"]})
    if not user or user["password"] != data["password"]:
        return jsonify({"error": "Invalid email or password"}), 401
    return jsonify({"user_id": str(user["_id"]), "name": user["name"]})

# -------------------------------
# 👤 Profile: Save & Get
# -------------------------------

@app.route("/save-profile", methods=["POST"])
def save_profile():
    try:
        data = request.get_json()
        print("📦 Incoming /save-profile payload:", data)

        if not data:
            return jsonify({"error": "Empty or invalid JSON"}), 400

        required_keys = ["user_id", "age", "gender", "activity_level", "calorie_target"]
        missing_keys = [k for k in required_keys if k not in data]
        if missing_keys:
            return jsonify({"error": f"Missing keys: {', '.join(missing_keys)}"}), 400

        profiles_collection.update_one(
            {"user_id": data["user_id"]},
            {"$set": data},
            upsert=True
        )
        return jsonify({"message": "Profile saved"}), 200
    except Exception as e:
        print("❌ save_profile Exception:", str(e))
        return jsonify({"error": str(e)}), 500

@app.route("/get-profile", methods=["GET"])
def get_profile():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400

        profile = profiles_collection.find_one({"user_id": user_id})
        if not profile:
            return jsonify({"error": "Profile not found"}), 404

        profile["_id"] = str(profile["_id"])
        return jsonify(profile), 200
    except Exception as e:
        print("❌ get_profile Exception:", str(e))
        return jsonify({"error": str(e)}), 500

# -------------------------------
# 📷 Analyze Image via Gemini
# -------------------------------

@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        image_file = request.files["image"]
        user_id = request.form.get("user_id", "guest")
        image_bytes = image_file.read()

        result = full_image_analysis(image_bytes)
        result["user_id"] = user_id
        return jsonify(result)
    except Exception as e:
        print("❌ analyze Exception:", str(e))
        return jsonify({"error": str(e)}), 500

# -------------------------------
# 🍽️ Save & Retrieve Meals
# -------------------------------

@app.route("/save-meal", methods=["POST"])
def save_meal():
    try:
        data = request.get_json()
        print("📦 Incoming /save-meal payload:", data)

        required = ["user_id", "dish_prediction", "image_description", "nutrition_info"]
        missing = [k for k in required if k not in data]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

        meal = {
            "user_id": data["user_id"],
            "dish_prediction": data["dish_prediction"],
            "image_description": data["image_description"],
            "nutrition_info": data["nutrition_info"],
            "hidden_ingredients": data.get("hidden_ingredients", ""),
            "image": data.get("image", None)
        }

        meals_collection.insert_one(meal)
        return jsonify({"message": "Meal saved successfully"}), 200
    except Exception as e:
        print("❌ save_meal Exception:", str(e))
        return jsonify({"error": str(e)}), 500

@app.route("/user-meals", methods=["GET"])
def get_user_meals():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400

        meals = list(meals_collection.find({"user_id": user_id}))
        for meal in meals:
            meal["_id"] = str(meal["_id"])
        return jsonify(meals)
    except Exception as e:
        print("❌ get_user_meals Exception:", str(e))
        return jsonify({"error": str(e)}), 500

# -------------------------------
# 🚀 App Start (Render-compatible)
# -------------------------------

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
