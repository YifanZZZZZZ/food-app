from flask import Flask, request, jsonify
import tempfile
import os
import base64
from model_pipeline import full_image_analysis
from auth import auth_bp
from pymongo import MongoClient

# --- Flask App Setup ---
app = Flask(__name__)
app.secret_key = 'your-secret'
app.register_blueprint(auth_bp)

# --- MongoDB Setup ---
client = MongoClient(os.getenv("MONGO_URI"))
db = client[os.getenv("MONGO_DB", "food-app-swift")]
meals_collection = db["meals"]
profiles_collection = db["profiles"]

# --- Analyze Image Upload ---
@app.route("/analyze", methods=["POST"])
def analyze():
    if 'image' not in request.files or 'user_id' not in request.form:
        return jsonify({"error": "Missing image or user_id"}), 400

    image_file = request.files['image']
    user_id = request.form['user_id']

    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
        image_file.save(tmp.name)
        result = full_image_analysis(tmp.name, user_id)

    return jsonify(result)

# --- Get Meals for User ---
@app.route("/user-meals", methods=["GET"])
def user_meals():
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"error": "Missing user_id"}), 400

    meals = list(meals_collection.find({"user_id": user_id}).sort("timestamp", -1))
    for meal in meals:
        meal["_id"] = str(meal["_id"])
        meal["timestamp"] = meal["timestamp"].isoformat()
        if "image" in meal:
            meal["image"] = base64.b64encode(meal["image"]).decode("utf-8")

    return jsonify(meals)

# --- ✅ NEW: Get Saved Profile for User ---
@app.route("/profile", methods=["GET"])
def get_profile():
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"error": "Missing user_id"}), 400

    profile = profiles_collection.find_one({"user_id": user_id})
    if not profile:
        return jsonify({"error": "Profile not found"}), 404

    profile["_id"] = str(profile["_id"])
    return jsonify(profile)

# --- Start Server ---
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    app.run(host="0.0.0.0", port=port)
