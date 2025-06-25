from flask import Flask, request, jsonify
import tempfile
import os
from model_pipeline import full_image_analysis
from auth import auth_bp
from pymongo import MongoClient

app = Flask(__name__)
app.secret_key = 'your-secret'
app.register_blueprint(auth_bp)

client = MongoClient(os.getenv("MONGO_URI"))
db = client[os.getenv("MONGO_DB", "food-app-swift")]
meals_collection = db["meals"]

@app.route("/analyze", methods=["POST"])
def analyze():
    if 'image' not in request.files or 'user_id' not in request.form:
        return jsonify({"error": "Missing image or user_id"}), 400
    image_file = request.files['image']
    user_id = request.form['user_id']

    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
        image_file.save(tmp.name)
        result = full_image_analysis(tmp.name, user_id)

    # Save meal to MongoDB
    result["user_id"] = user_id
    meals_collection.insert_one(result)
    return jsonify(result)

@app.route("/user-meals", methods=["GET"])
def user_meals():
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"error": "Missing user_id"}), 400
    meals = list(meals_collection.find({"user_id": user_id}))
    for m in meals:
        m["_id"] = str(m["_id"])
    return jsonify(meals)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    app.run(host="0.0.0.0", port=port)
