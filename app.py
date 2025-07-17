from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import os
from pymongo import MongoClient
from bson import ObjectId
from model_pipeline import full_image_analysis, validate_image_for_analysis
import base64
import traceback
import time
from io import BytesIO
from PIL import Image
import hashlib
from datetime import datetime
import google.generativeai as genai

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app, supports_credentials=True)

# Configure MongoDB with connection pooling
client = MongoClient(
    os.getenv("MONGO_URI"),
    maxPoolSize=50,
    minPoolSize=10,
    maxIdleTimeMS=30000,
    serverSelectionTimeoutMS=5000
)
db = client[os.getenv("MONGO_DB", "food-app-swift")]

# Create indexes for better performance
users_collection = db["users"]
users_collection.create_index("email", unique=True)

profiles_collection = db["profiles"]
profiles_collection.create_index("user_id")

meals_collection = db["meals"]
meals_collection.create_index([("user_id", 1), ("saved_at", -1)])

# Configure Gemini for nutrition recalculation
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
gemini_model = genai.GenerativeModel('gemini-1.5-flash')


# Debug Process
print("✅ Connected to MongoDB URI:", os.getenv("MONGO_URI"))
print("✅ Using DB name:", db.name)

@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok", "timestamp": datetime.now().isoformat()}), 200

@app.route("/")
def home():
    return {"message": "Food Analyzer Backend is Running", "version": "2.1", "based_on": "Working Web App Backend"}, 200

@app.route("/health", methods=["GET"])
def health():
    try:
        # Check MongoDB connection
        client.admin.command('ping')
        
        # Check Gemini API key
        gemini_ok = bool(os.getenv("GEMINI_API_KEY"))
        
        return jsonify({
            "status": "healthy",
            "mongodb": "connected",
            "gemini": "configured" if gemini_ok else "missing API key",
            "analysis_mode": "working_web_app_based",
            "backend_version": "proven_stable",
            "timestamp": datetime.now().isoformat()
        }), 200
    except Exception as e:
        return jsonify({
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }), 503

@app.route("/register", methods=["POST"])
def register():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
        
        # Validate required fields
        required_fields = ["name", "email", "password"]
        missing_fields = [field for field in required_fields if field not in data or not data[field]]
        if missing_fields:
            return jsonify({"error": f"Missing fields: {', '.join(missing_fields)}"}), 400
            
        # Check if email already exists
        if users_collection.find_one({"email": data["email"]}):
            return jsonify({"error": "Email already registered"}), 409

        # Hash password with SHA256
        hashed_pw = hashlib.sha256(data["password"].encode()).hexdigest()
        
        user = {
            "name": data["name"],
            "email": data["email"],
            "password": hashed_pw,
            "created_at": datetime.now().isoformat()
        }
        
        result = users_collection.insert_one(user)
        print(f"✅ Inserted user with ID: {result.inserted_id}")
        return jsonify({
            "user_id": str(result.inserted_id), 
            "name": data["name"]
        }), 200
        
    except Exception as e:
        print(f"❌ Register error: {str(e)}")
        return jsonify({"error": "Registration failed"}), 500

@app.route("/login", methods=["POST"])
def login():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
        
        # Validate required fields
        if not data.get("email") or not data.get("password"):
            return jsonify({"error": "Email and password required"}), 400
            
        user = users_collection.find_one({"email": data["email"]})
        if not user:
            return jsonify({"error": "Invalid email or password"}), 401

        # Check password
        input_pw_hash = hashlib.sha256(data["password"].encode()).hexdigest()
        if user["password"] != input_pw_hash:
            return jsonify({"error": "Invalid email or password"}), 401

        return jsonify({
            "user_id": str(user["_id"]), 
            "name": user["name"]
        }), 200
        
    except Exception as e:
        print(f"❌ Login error: {str(e)}")
        return jsonify({"error": "Login failed"}), 500

@app.route("/save-profile", methods=["POST"])
def save_profile():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty or invalid JSON"}), 400

        user_id = data.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id"}), 400

        # Remove user_id from data before saving
        profile_data = {k: v for k, v in data.items() if k != "user_id"}
        profile_data["updated_at"] = datetime.now().isoformat()
        
        profiles_collection.update_one(
            {"user_id": user_id},
            {"$set": profile_data},
            upsert=True
        )
        
        return jsonify({"message": "Profile saved"}), 200
    except Exception as e:
        print(f"❌ Save profile error: {str(e)}")
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
        print(f"❌ Get profile error: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/analyze", methods=["POST"])
def analyze():
    """Image analysis endpoint - based on working web app"""
    try:
        if "image" not in request.files:
            return jsonify({"error": "No image part in the request"}), 400

        image_file = request.files["image"]
        user_id = request.form.get("user_id", "guest")

        # Validate file size (limit to 10MB)
        image_file.seek(0, 2)  # Seek to end
        file_size = image_file.tell()
        image_file.seek(0)  # Reset to beginning
        
        if file_size > 10 * 1024 * 1024:  # 10MB limit
            return jsonify({"error": "Image too large. Please use an image under 10MB"}), 413

        if file_size < 1024:  # Too small
            return jsonify({"error": "Image too small. Please use a clearer image"}), 400

        filename = f"image_{int(time.time())}.png"
        image_path = os.path.join("/tmp", filename)
        image_file.save(image_path)

        print(f"📸 Saved image to: {image_path} (size: {file_size / 1024 / 1024:.2f}MB)")

        # Validate image before analysis
        is_valid, validation_msg = validate_image_for_analysis(image_path)
        if not is_valid:
            try:
                os.remove(image_path)
            except:
                pass
            return jsonify({"error": f"Invalid image: {validation_msg}"}), 400

        # Perform analysis with timeout handling
        from concurrent.futures import ThreadPoolExecutor, TimeoutError
        import concurrent.futures
        
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(full_image_analysis, image_path, user_id)
            try:
                # Give it 90 seconds to complete
                result = future.result(timeout=90)
                
                # Check if analysis actually succeeded
                if "error" in result:
                    print(f"⚠️ Analysis contained errors: {result.get('error', 'Unknown error')}")
                    # Clean up and return error
                    try:
                        os.remove(image_path)
                    except:
                        pass
                    return jsonify({
                        "error": f"Analysis failed: {result.get('error', 'Unknown error')}",
                        "suggestion": "Please try with a clearer image of food"
                    }), 500
                
                # Validate that we got meaningful results
                if (result.get("dish_prediction", "").lower().startswith("analysis failed") or
                    result.get("dish_prediction", "").lower().startswith("could not identify") or
                    result.get("dish_prediction", "").lower().startswith("unable to analyze")):
                    try:
                        os.remove(image_path)
                    except:
                        pass
                    return jsonify({
                        "error": "Unable to analyze this image",
                        "suggestion": "Please ensure the image clearly shows food items"
                    }), 422
                
            except concurrent.futures.TimeoutError:
                print("⏱️ Analysis timeout")
                try:
                    os.remove(image_path)
                except:
                    pass
                return jsonify({
                    "error": "Analysis timeout",
                    "suggestion": "Please try with a simpler or clearer image"
                }), 408
        
        result["user_id"] = user_id
        print(f"✅ Analysis completed for {filename}")
        print(f"📊 Dish: {result.get('dish_prediction', 'Unknown')}")
        print(f"📊 Hidden ingredients: {result.get('hidden_ingredients', 'None')[:100]}...")
        print(f"⏱️ Analysis time: {result.get('analysis_time', 0):.2f}s")
        
        # Debug: Check if hidden ingredients exist
        if result.get('hidden_ingredients'):
            print(f"🔍 Hidden ingredients length: {len(result['hidden_ingredients'])}")
            print(f"🔍 Hidden ingredients preview: {result['hidden_ingredients'][:200]}...")
        else:
            print("⚠️ No hidden ingredients in result")
        
        # Clean up
        try:
            os.remove(image_path)
        except:
            pass
            
        return jsonify(result), 200

    except Exception as e:
        print("❌ analyze Exception:", str(e))
        traceback.print_exc()
        # Clean up on error
        try:
            if 'image_path' in locals():
                os.remove(image_path)
        except:
            pass
        return jsonify({
            "error": "Analysis failed",
            "details": str(e)
        }), 500

@app.route("/analyze-enhanced", methods=["POST"])
def analyze_enhanced():
    """Enhanced analysis endpoint - redirects to main analyze since it's already fully dynamic"""
    try:
        # Since our main analysis is already fully dynamic and enhanced, 
        # we can redirect to it with additional context
        print("🔄 Enhanced analysis requested - using fully dynamic analysis")
        return analyze()
        
    except Exception as e:
        print("❌ Enhanced analyze Exception:", str(e))
        traceback.print_exc()
        return jsonify({
            "error": "Enhanced analysis failed",
            "details": str(e)
        }), 500

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

        # Process images
        image = data.get("image", None)
        image_full = data.get("image_full") or image
        image_thumb = data.get("image_thumb") or (compress_base64_image(image) if image else None)

        # Build meal document
        meal = {
            "user_id": data["user_id"],
            "dish_prediction": data["dish_prediction"],
            "image_description": data["image_description"],
            "nutrition_info": data["nutrition_info"],
            "hidden_ingredients": data.get("hidden_ingredients", ""),
            "image_full": image_full,
            "image_thumb": image_thumb,
            "meal_type": data.get("meal_type", "Lunch"),
            "saved_at": data.get("saved_at", datetime.now().isoformat()),
            "analysis_method": "dynamic_ai",
            "contains_hardcoded_values": False
        }

        result = meals_collection.insert_one(meal)
        return jsonify({
            "message": "Meal saved successfully",
            "meal_id": str(result.inserted_id)
        }), 200
        
    except Exception as e:
        print(f"❌ Error in save_meal: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/user-meals", methods=["GET"])
def get_user_meals():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400

        # Query meals for the user, sorted by date
        meals = list(meals_collection.find(
            {"user_id": user_id}
        ).sort("saved_at", -1))
        
        # Process each meal to ensure compatibility
        processed_meals = []
        for meal in meals:
            # Convert ObjectId to string
            meal["_id"] = str(meal["_id"])
            
            # Handle different image storage formats
            if "image" in meal and isinstance(meal["image"], bytes):
                meal["image_thumb"] = base64.b64encode(meal["image"]).decode('utf-8')
                meal["image_full"] = meal["image_thumb"]
                del meal["image"]
            
            # Ensure all required fields exist
            meal.setdefault("dish_prediction", meal.get("dish", "Unknown Dish"))
            meal.setdefault("image_description", meal.get("visible_ingredients", ""))
            meal.setdefault("hidden_ingredients", "")
            meal.setdefault("nutrition_info", "")
            meal.setdefault("meal_type", "Lunch")
            
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
        
        return jsonify(processed_meals), 200
        
    except Exception as e:
        print(f"❌ Error in get_user_meals: {str(e)}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route("/update-meal", methods=["PUT"])
def update_meal():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
        
        meal_id = data.get("meal_id")
        if not meal_id:
            return jsonify({"error": "Missing meal_id"}), 400
        
        # Prepare update data
        update_data = {}
        if "dish_prediction" in data:
            update_data["dish_prediction"] = data["dish_prediction"]
        if "image_description" in data:
            update_data["image_description"] = data["image_description"]
        if "nutrition_info" in data:
            update_data["nutrition_info"] = data["nutrition_info"]
        if "meal_type" in data:
            update_data["meal_type"] = data["meal_type"]
            
        update_data["updated_at"] = datetime.now().isoformat()
        update_data["last_modified_method"] = "user_edit"
        
        # Update meal in database
        result = meals_collection.update_one(
            {"_id": ObjectId(meal_id)},
            {"$set": update_data}
        )
        
        if result.modified_count > 0:
            return jsonify({"message": "Meal updated successfully"}), 200
        else:
            return jsonify({"error": "Meal not found or no changes made"}), 404
            
    except Exception as e:
        print(f"❌ Error in update_meal: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/delete-meal", methods=["DELETE"])
def delete_meal():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
        
        meal_id = data.get("meal_id")
        if not meal_id:
            return jsonify({"error": "Missing meal_id"}), 400
        
        # Delete meal from database
        result = meals_collection.delete_one({"_id": ObjectId(meal_id)})
        
        if result.deleted_count > 0:
            return jsonify({"message": "Meal deleted successfully"}), 200
        else:
            return jsonify({"error": "Meal not found"}), 404
            
    except Exception as e:
        print(f"❌ Error in delete_meal: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/recalculate-nutrition", methods=["POST"])
def recalculate_nutrition():
    """Fully dynamic nutrition recalculation endpoint"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
        
        ingredients = data.get("ingredients", "")
        user_id = data.get("user_id", "")
        
        if not ingredients:
            return jsonify({"error": "No ingredients provided"}), 400
        
        # Use enhanced recalculation from model_pipeline
        from model_pipeline import recalculate_nutrition_enhanced
        
        print(f"🔄 Recalculating nutrition for user {user_id}")
        print(f"📋 Ingredients: {ingredients[:100]}...")
        
        try:
            nutrition_info = recalculate_nutrition_enhanced(ingredients)
            
            # Check if recalculation failed
            if "Recalculation failed" in nutrition_info:
                return jsonify({
                    "error": "Nutrition recalculation failed",
                    "details": "Unable to calculate nutrition from provided ingredients"
                }), 500
            
            return jsonify({
                "nutrition_info": nutrition_info,
                "calculation_method": "dynamic_ai",
                "contains_hardcoded_values": False
            }), 200
            
        except Exception as e:
            print(f"❌ Recalculation error: {str(e)}")
            return jsonify({
                "error": "Nutrition recalculation failed",
                "details": str(e)
            }), 500
            
    except Exception as e:
        print(f"❌ Error in recalculate_nutrition: {str(e)}")
        return jsonify({"error": str(e)}), 500
    
    
# Add these endpoints to your app.py file

@app.route("/add-exercise", methods=["POST"])
def add_exercise():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
        
        required = ["user_id", "exercise_type", "duration"]
        missing = [k for k in required if k not in data]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400
        
        exercise = {
            "user_id": data["user_id"],
            "exercise_type": data["exercise_type"],
            "duration": data["duration"],
            "intensity": data.get("intensity", "Moderate"),
            "calories_burned": data.get("calories_burned", 0),
            "notes": data.get("notes", ""),
            "recorded_at": data.get("recorded_at", datetime.now().isoformat())
        }
        
        # Create exercise collection if it doesn't exist
        exercises_collection = db["exercise"]
        exercises_collection.create_index([("user_id", 1), ("recorded_at", -1)])
        
        result = exercises_collection.insert_one(exercise)
        return jsonify({
            "message": "Exercise added successfully",
            "exercise_id": str(result.inserted_id)
        }), 200
        
    except Exception as e:
        print(f"❌ Error in add_exercise: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/user-exercise", methods=["GET"])
def get_user_exercise():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400
        
        exercises_collection = db["exercise"]
        exercises = list(exercises_collection.find(
            {"user_id": user_id}
        ).sort("recorded_at", -1))
        
        for exercise in exercises:
            exercise["_id"] = str(exercise["_id"])
        
        return jsonify(exercises), 200
        
    except Exception as e:
        print(f"❌ Error in get_user_exercise: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/add-water", methods=["POST"])
def add_water():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
        
        required = ["user_id", "amount"]
        missing = [k for k in required if k not in data]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400
        
        water_entry = {
            "user_id": data["user_id"],
            "amount": data["amount"],
            "recorded_at": data.get("recorded_at", datetime.now().isoformat())
        }
        
        # Create water collection if it doesn't exist
        water_collection = db["water"]
        water_collection.create_index([("user_id", 1), ("recorded_at", -1)])
        
        result = water_collection.insert_one(water_entry)
        return jsonify({
            "message": "Water intake added successfully",
            "water_id": str(result.inserted_id)
        }), 200
        
    except Exception as e:
        print(f"❌ Error in add_water: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/user-water", methods=["GET"])
def get_user_water():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400
        
        water_collection = db["water"]
        water_entries = list(water_collection.find(
            {"user_id": user_id}
        ).sort("recorded_at", -1))
        
        for entry in water_entries:
            entry["_id"] = str(entry["_id"])
        
        return jsonify(water_entries), 200
        
    except Exception as e:
        print(f"❌ Error in get_user_water: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/add-weight", methods=["POST"])
def add_weight():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Empty request"}), 400
        
        required = ["user_id", "weight"]
        missing = [k for k in required if k not in data]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400
        
        weight_entry = {
            "user_id": data["user_id"],
            "weight": data["weight"],
            "recorded_at": data.get("recorded_at", datetime.now().isoformat())
        }
        
        # Create weight collection if it doesn't exist
        weight_collection = db["weight"]
        weight_collection.create_index([("user_id", 1), ("recorded_at", -1)])
        
        result = weight_collection.insert_one(weight_entry)
        return jsonify({
            "message": "Weight entry added successfully",
            "weight_id": str(result.inserted_id)
        }), 200
        
    except Exception as e:
        print(f"❌ Error in add_weight: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/user-weight", methods=["GET"])
def get_user_weight():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400
        
        weight_collection = db["weight"]
        weight_entries = list(weight_collection.find(
            {"user_id": user_id}
        ).sort("recorded_at", -1))
        
        for entry in weight_entries:
            entry["_id"] = str(entry["_id"])
        
        return jsonify(weight_entries), 200
        
    except Exception as e:
        print(f"❌ Error in get_user_weight: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/dashboard-stats", methods=["GET"])
def get_dashboard_stats():
    """Get comprehensive dashboard statistics"""
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400
        
        # Get current date info
        now = datetime.now()
        today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        week_start = today - timedelta(days=today.weekday())
        month_start = today.replace(day=1)
        
        # Initialize collections
        meals_collection = db["meals"]
        water_collection = db["water"]
        exercise_collection = db["exercise"]
        weight_collection = db["weight"]
        
        # Get meal stats
        meals = list(meals_collection.find({"user_id": user_id}))
        today_meals = [m for m in meals if datetime.fromisoformat(m.get("saved_at", "").replace('Z', '+00:00')).date() == today.date()]
        week_meals = [m for m in meals if datetime.fromisoformat(m.get("saved_at", "").replace('Z', '+00:00')) >= week_start]
        month_meals = [m for m in meals if datetime.fromisoformat(m.get("saved_at", "").replace('Z', '+00:00')) >= month_start]
        
        # Get water stats
        water_entries = list(water_collection.find({"user_id": user_id}))
        today_water = sum(w["amount"] for w in water_entries if datetime.fromisoformat(w.get("recorded_at", "").replace('Z', '+00:00')).date() == today.date())
        week_water = sum(w["amount"] for w in water_entries if datetime.fromisoformat(w.get("recorded_at", "").replace('Z', '+00:00')) >= week_start)
        
        # Get exercise stats
        exercise_entries = list(exercise_collection.find({"user_id": user_id}))
        today_exercise = sum(e["duration"] for e in exercise_entries if datetime.fromisoformat(e.get("recorded_at", "").replace('Z', '+00:00')).date() == today.date())
        week_exercise = sum(e["duration"] for e in exercise_entries if datetime.fromisoformat(e.get("recorded_at", "").replace('Z', '+00:00')) >= week_start)
        
        # Get weight stats
        weight_entries = list(weight_collection.find({"user_id": user_id}).sort("recorded_at", -1))
        current_weight = weight_entries[0]["weight"] if weight_entries else 0
        
        # Calculate streak (simplified)
        streak = 0
        check_date = today
        for i in range(30):  # Check last 30 days
            day_meals = [m for m in meals if datetime.fromisoformat(m.get("saved_at", "").replace('Z', '+00:00')).date() == check_date.date()]
            if day_meals:
                streak += 1
                check_date -= timedelta(days=1)
            else:
                break
        
        return jsonify({
            "today": {
                "meals": len(today_meals),
                "water": today_water,
                "exercise": today_exercise
            },
            "week": {
                "meals": len(week_meals),
                "water": week_water,
                "exercise": week_exercise
            },
            "month": {
                "meals": len(month_meals)
            },
            "current_weight": current_weight,
            "streak": streak,
            "timestamp": now.isoformat()
        }), 200
        
    except Exception as e:
        print(f"❌ Error in get_dashboard_stats: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/user-insights", methods=["GET"])
def get_user_insights():
    """Get personalized health insights"""
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id parameter"}), 400
        
        # Get user profile for goals
        profile = profiles_collection.find_one({"user_id": user_id})
        if not profile:
            return jsonify({"error": "Profile not found"}), 404
        
        calorie_target = profile.get("calorie_target", 2000)
        
        # Get today's data
        today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        
        # Get today's meals
        today_meals = list(meals_collection.find({
            "user_id": user_id,
            "saved_at": {"$gte": today.isoformat()}
        }))
        
        # Calculate today's calories
        today_calories = 0
        for meal in today_meals:
            nutrition = meal.get("nutrition_info", "")
            for line in nutrition.split('\n'):
                if 'calories' in line.lower():
                    parts = line.split('|')
                    if len(parts) >= 2:
                        try:
                            today_calories += int(parts[1].strip())
                        except:
                            pass
        
        # Get today's water
        today_water = sum(
            w["amount"] for w in db["water"].find({
                "user_id": user_id,
                "recorded_at": {"$gte": today.isoformat()}
            })
        )
        
        # Get today's exercise
        today_exercise = sum(
            e["duration"] for e in db["exercise"].find({
                "user_id": user_id,
                "recorded_at": {"$gte": today.isoformat()}
            })
        )
        
        # Generate insights
        insights = []
        
        # Calorie insights
        if today_calories > calorie_target * 1.2:
            insights.append({
                "type": "warning",
                "title": "High Calorie Intake",
                "message": f"You've consumed {today_calories} calories, which is above your {calorie_target} goal.",
                "icon": "exclamationmark.triangle.fill",
                "color": "red"
            })
        elif today_calories < calorie_target * 0.8:
            insights.append({
                "type": "info",
                "title": "Low Calorie Intake",
                "message": f"You've only consumed {today_calories} calories today. Make sure you're eating enough!",
                "icon": "info.circle.fill",
                "color": "blue"
            })
        
        # Water insights
        if today_water < 1000:
            insights.append({
                "type": "reminder",
                "title": "Stay Hydrated",
                "message": f"You've only had {int(today_water)}ml of water today. Try to drink more!",
                "icon": "drop.fill",
                "color": "blue"
            })
        
        # Exercise insights
        if today_exercise == 0:
            insights.append({
                "type": "motivation",
                "title": "Get Moving",
                "message": "You haven't logged any exercise today. Even a short walk counts!",
                "icon": "figure.walk",
                "color": "green"
            })
        
        return jsonify({
            "insights": insights,
            "today_stats": {
                "calories": today_calories,
                "water": today_water,
                "exercise": today_exercise
            },
            "goals": {
                "calories": calorie_target,
                "water": 2000,
                "exercise": 30
            }
        }), 200
        
    except Exception as e:
        print(f"❌ Error in get_user_insights: {str(e)}")
        return jsonify({"error": str(e)}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500

@app.errorhandler(413)
def payload_too_large(error):
    return jsonify({"error": "Request payload too large"}), 413

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"🚀 Starting Food Analyzer Backend on port {port}")
    print(f"✅ Based on proven working web app backend")
    print(f"🤖 Using Gemini AI with tested prompts")
    print(f"📱 Compatible with Swift frontend")
    app.run(host="0.0.0.0", port=port, threaded=True)
