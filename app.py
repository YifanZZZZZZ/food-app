from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
from model_pipeline import full_image_analysis
import base64
import os

app = Flask(__name__)
CORS(app)

# MongoDB setup (replace credentials if needed)
client = MongoClient("mongodb+srv://<username>:<password>@cluster.mongodb.net/")
db = client["food_app"]
meals_collection = db["meals"]
users_collection = db["users"]
profiles_collection = db["profiles"]

@app.route("/")
def home():
    return "Food Analyzer Backend is Running"

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

@app.route("/save-profile", methods=["POST"])
def save_profile():
    data = request.get_json()
    user_id = data["user_id"]
    profiles_collection.update_one(
        {"user_id": user_id},
        {"$set": data},
        upsert=True
    )
    return "Profile saved"

@app.route("/analyze", methods=["POST"])
def analyze():
    image_file = request.files["image"]
    user_id = request.form.get("user_id", "guest")
    image_bytes = image_file.read()

    result = full_image_analysis(image_bytes)
    result["user_id"] = user_id
    return jsonify(result)

@app.route("/user-meals", methods=["GET"])
def get_user_meals():
    user_id = request.args.get("user_id")
    meals = list(meals_collection.find({"user_id": user_id}))
    for meal in meals:
        meal["_id"] = str(meal["_id"])
    return jsonify(meals)

@app.route("/save-meal", methods=["POST"])
def save_meal():
    try:
        data = request.get_json()
        required = ["user_id", "dish_prediction", "image_description", "nutrition_info"]
        if not all(k in data for k in required):
            return jsonify({"error": "Missing required fields"}), 400
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

if __name__ == "__main__":
    app.run(debug=True)
