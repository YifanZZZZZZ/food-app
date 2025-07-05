from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import os
from pymongo import MongoClient
from model_pipeline import full_image_analysis
import base64
import traceback
import time
from io import BytesIO
from PIL import Image
import hashlib

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app, supports_credentials=True)

client = MongoClient(os.getenv("MONGO_URI"))
db = client[os.getenv("MONGO_DB", "food-app-swift")]
users_collection = db["users"]
profiles_collection = db["profiles"]
meals_collection = db["meals"]

@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"}), 200

@app.route("/")
def home():
    return {"message": "Food Analyzer Backend is Running"}, 200

@app.route("/register", methods=["POST"])
def register():
    data = request.get_json()
    if not data:
        return jsonify({"error": "Empty request"}), 400
        
    if users_collection.find_one({"email": data["email"]}):
        return jsonify({"error": "Email already registered"}), 409

    # Use SHA256 for better security than base64
    hashed_pw = hashlib.sha256(data["password"].encode()).hexdigest()
    user = {
        "name": data["name"],
        "email": data["email"],
        "password": hashed_pw
    }
    result = users_collection.insert_one(user)
    return jsonify({"user_id": str(result.inserted_id), "name": data["name"]}), 200

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()
    if not data:
        return jsonify({"error": "Empty request"}), 400
        
    user = users_collection.find_one({"email": data["email"]})
    if not user:
        return jsonify({"error": "Invalid email or password"}), 401

    # Check password with SHA256
    input_pw_hash = hashlib.sha256(data["password"].encode()).hexdigest()
    if user["password"] != input_pw_hash:
        return jsonify({"error": "Invalid email or password"}), 401

    return jsonify({"user_id": str(user["_id"]), "name": user["name"]}), 200

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

@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        if "image" not in request.files:
            return jsonify({"error": "No image part in the request"}), 400

        image_file = request.files["image"]
        user_id = request.form.get("user_id", "guest")

        filename = f"image_{int(time.time())}.png"
        image_path = os.path.join("/tmp", filename)
        image_file.save(image_path)

        print(f"📸 Saved image to: {image_path}")

        # Add timeout protection
        from concurrent.futures import ThreadPoolExecutor, TimeoutError
        import concurrent.futures
        
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(full_image_analysis, image_path, user_id)
            try:
                # Give it 120 seconds to complete
                result = future.result(timeout=120)
            except concurrent.futures.TimeoutError:
                print("⏱️ Analysis timeout - using fallback")
                # Return a simplified result
                result = {
                    "dish_prediction": "Food Item",
                    "image_description": "Analysis is taking longer than expected. Please try again.",
                    "hidden_ingredients": "",
                    "nutrition_info": "Calories | 0 | kcal | Estimation pending"
                }
        
        result["user_id"] = user_id
        print(f"✅ Analysis completed for {filename}")
        
        # Clean up
        try:
            os.remove(image_path)
        except:
            pass
            
        return jsonify(result), 200

    except Exception as e:
        print("❌ analyze Exception:", str(e))
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

def compress_base64_image(base64_str, quality=5):
    try:
        image_data = base64.b64decode(base64_str)
        image = Image.open(BytesIO(image_data)).convert("RGB")
        buffer = BytesIO()
        image.save(buffer, format="JPEG", quality=quality)
        compressed_data = buffer.getvalue()
        return base64.b64encode(compressed_data).decode("utf-8")
    except Exception as e:
        print("❌ Compression Error:", str(e))
        return None

@app.route("/save-meal", methods=["POST"])
def save_meal():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
            
        required = ["user_id", "dish_prediction", "image_description", "nutrition_info"]
        missing = [k for k in required if k not in data]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

        image = data.get("image", None)
        image_full = data.get("image_full") or image
        image_thumb = data.get("image_thumb") or (compress_base64_image(image) if image else None)

        meal = {
            "user_id": data["user_id"],
            "dish_prediction": data["dish_prediction"],
            "image_description": data["image_description"],
            "nutrition_info": data["nutrition_info"],
            "hidden_ingredients": data.get("hidden_ingredients", ""),
            "image_full": image_full,
            "image_thumb": image_thumb,
            "saved_at": data.get("saved_at", time.strftime("%Y-%m-%dT%H:%M:%S"))
        }

        meals_collection.insert_one(meal)
        return jsonify({"message": "Meal saved successfully"}), 200
    except Exception as e:
        print(f"❌ Error in save_meal: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/user-meals", methods=["GET"])
def get_user_meals():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400

        meals = list(meals_collection.find({"user_id": user_id}))
        
        # Process each meal to ensure compatibility
        processed_meals = []
        for meal in meals:
            # Convert ObjectId to string
            meal["_id"] = str(meal["_id"])
            
            # Handle different image storage formats
            if "image" in meal and isinstance(meal["image"], bytes):
                # If image is stored as Binary, convert to base64
                meal["image_thumb"] = base64.b64encode(meal["image"]).decode('utf-8')
                meal["image_full"] = meal["image_thumb"]  # Use same image for both
                del meal["image"]  # Remove the binary field
            
            # Ensure all required fields exist with correct names
            meal.setdefault("dish_prediction", meal.get("dish", "Unknown Dish"))
            meal.setdefault("image_description", meal.get("visible_ingredients", ""))
            meal.setdefault("hidden_ingredients", "")
            meal.setdefault("nutrition_info", "")
            
            # Handle timestamp/saved_at field
            if "timestamp" in meal:
                if hasattr(meal["timestamp"], 'isoformat'):
                    meal["saved_at"] = meal["timestamp"].isoformat()
                else:
                    meal["saved_at"] = str(meal["timestamp"])
            else:
                meal.setdefault("saved_at", "")
            
            # Remove fields that iOS doesn't expect
            fields_to_remove = ["timestamp", "visible_ingredients", "image_filename", "dish"]
            for field in fields_to_remove:
                meal.pop(field, None)
            
            # Ensure image fields exist
            meal.setdefault("image_full", "")
            meal.setdefault("image_thumb", "")
            
            processed_meals.append(meal)

        print(f"🔍 Looking up meals for user_id: {user_id}")
        print(f"📦 Total meals found: {len(processed_meals)}")
        
        # Log first meal structure for debugging
        if processed_meals:
            print(f"📝 First meal keys: {list(processed_meals[0].keys())}")

        return jsonify(processed_meals), 200
    except Exception as e:
        print(f"❌ Error in get_user_meals: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, threaded=True)