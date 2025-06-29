# app.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import os
from pymongo import MongoClient
from model_pipeline import full_image_analysis
import base64
import traceback
import time

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app, supports_credentials=True)

# MongoDB connection
client = MongoClient(os.getenv("MONGO_URI"))
db = client[os.getenv("MONGO_DB", "food-app-swift")]
users_collection = db["users"]
profiles_collection = db["profiles"]
meals_collection = db["meals"]

# -------------------------------
# 🔗 Health Check
# -------------------------------
@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"}), 200

@app.route("/")
def home():
    return {"message": "Food Analyzer Backend is Running"}, 200

# -------------------------------
# 🔐 Register Endpoint
# -------------------------------
@app.route("/register", methods=["POST"])
def register():
    data = request.get_json()
    if users_collection.find_one({"email": data["email"]}):
        return jsonify({"error": "Email already registered"}), 409

    hashed_pw = base64.b64encode(data["password"].encode()).decode()
    user = {
        "name": data["name"],
        "email": data["email"],
        "password": hashed_pw
    }
    result = users_collection.insert_one(user)
    return jsonify({"user_id": str(result.inserted_id), "name": data["name"]}), 200

# -------------------------------
# 🔐 Login Endpoint
# -------------------------------
@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    user = users_collection.find_one({"email": data["email"]})
    if not user:
        return jsonify({"error": "Invalid email or password"}), 401

    stored_pw = base64.b64decode(user["password"]).decode()
    if stored_pw != data["password"]:
        return jsonify({"error": "Invalid email or password"}), 401

    return jsonify({"user_id": str(user["_id"]), "name": user["name"]}), 200

# -------------------------------
# 👤 Save Profile
# -------------------------------
@app.route("/save-profile", methods=["POST"])
def save_profile():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty or invalid JSON"}), 400

        user_id = data.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id"}), 400

        profiles_collection.update_one(
            {"user_id": user_id},
            {"$set": {k: v for k, v in data.items() if k != "user_id"}},
            upsert=True
        )
        return jsonify({"message": "Profile saved"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# -------------------------------
# 👤 Get Profile
# -------------------------------
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
        return jsonify({"error": str(e)}), 500

# -------------------------------
# 📷 Analyze Image
# -------------------------------
@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        if "image" not in request.files:
            return jsonify({"error": "No image part in the request"}), 400

        image_file = request.files["image"]
        user_id = request.form.get("user_id", "guest")

        # Create unique image filename
        filename = f"image_{int(time.time())}.png"
        image_path = os.path.join("/tmp", filename)

        # Save image to disk
        image_file.save(image_path)
        print(f"📸 Saved image to: {image_path}")

        # Run full Gemini analysis
        result = full_image_analysis(image_path, user_id)
        result["user_id"] = user_id
        print(f"✅ Gemini analysis completed for {filename}")
        return jsonify(result), 200

    except Exception as e:
        print("❌ analyze Exception:", str(e))
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# -------------------------------
# 🍽️ Save Meal
# -------------------------------
@app.route("/save-meal", methods=["POST"])
def save_meal():
    try:
        data = request.get_json()
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
        return jsonify({"error": str(e)}), 500

# -------------------------------
# 🍽️ Get Meals
# -------------------------------
@app.route("/user-meals", methods=["GET"])
def get_user_meals():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400

        meals = list(meals_collection.find({"user_id": user_id}))
        for meal in meals:
            meal["_id"] = str(meal["_id"])
        return jsonify(meals), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# -------------------------------
# 🚀 Start App
# -------------------------------
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, threaded=True)
