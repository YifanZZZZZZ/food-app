import torch
from PIL import Image
import google.generativeai as genai
import base64
import os
import re
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
from io import BytesIO

# ---------- Load Environment ----------
load_dotenv()

# ---------- Device Config ----------
DEVICE = torch.device("mps" if torch.backends.mps.is_available() else
                      "cuda" if torch.cuda.is_available() else "cpu")

# ---------- Gemini API Setup ----------
GEN_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEN_API_KEY:
    raise ValueError("GEMINI_API_KEY is not set in environment variables.")

genai.configure(api_key=GEN_API_KEY)
gemini_model = genai.GenerativeModel('gemini-1.5-flash')

# ---------- MongoDB Setup ----------
mongo_uri = os.getenv("MONGO_URI")
mongo_db = os.getenv("MONGO_DB", "food-app-swift")
client = MongoClient(mongo_uri)
db = client[mongo_db]
meals_collection = db["meals"]

# ---------- Utility Functions ----------
def encode_image(image_path):
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode("utf-8")

def analyze_image_with_gemini_combined(image_path):
    """Single Gemini call for all analysis"""
    combined_prompt = """
    Analyze this food image and provide comprehensive information.
    
    First line: Just the dish name
    
    Then provide these sections:
    
    VISIBLE INGREDIENTS:
    List each visible ingredient in format: Ingredient | Quantity | Unit | Reasoning
    
    HIDDEN INGREDIENTS:
    List likely hidden ingredients (oils, spices, sauces) in format: Ingredient | Quantity | Unit | Reasoning
    
    NUTRITION INFO:
    List nutrition per serving in format: Nutrient | Value | Unit | Reasoning
    Must include: Calories, Protein, Fat, Carbohydrates, Fiber, Sugar, Sodium
    
    Rules:
    - Quantity must be a number only (no ranges like 1-2)
    - Be specific and realistic
    - Skip background items or utensils
    """
    
    try:
        image_data = encode_image(image_path)
        response = gemini_model.generate_content([
            combined_prompt,
            {"mime_type": "image/png", "data": image_data}
        ])
        return response.text
    except Exception as e:
        print(f"❌ Gemini error: {str(e)}")
        return f"Food Item\n\nVISIBLE INGREDIENTS:\nFood | 1 | serving | Unable to analyze\n\nHIDDEN INGREDIENTS:\nSeasoning | 1 | pinch | Estimated\n\nNUTRITION INFO:\nCalories | 200 | kcal | Estimated"

def parse_combined_response(response_text):
    """Parse the combined Gemini response into sections"""
    lines = response_text.strip().split('\n')
    
    # First line is dish name
    dish_name = lines[0].strip() if lines else "Unknown Dish"
    
    # Initialize sections
    visible_ingredients = []
    hidden_ingredients = []
    nutrition_info = []
    
    current_section = None
    
    for line in lines[1:]:
        line = line.strip()
        
        # Check for section headers
        if 'VISIBLE INGREDIENTS' in line.upper():
            current_section = 'visible'
            continue
        elif 'HIDDEN INGREDIENTS' in line.upper():
            current_section = 'hidden'
            continue
        elif 'NUTRITION' in line.upper():
            current_section = 'nutrition'
            continue
        
        # Parse ingredient/nutrition lines
        if '|' in line and current_section:
            if current_section == 'visible':
                visible_ingredients.append(line)
            elif current_section == 'hidden':
                hidden_ingredients.append(line)
            elif current_section == 'nutrition':
                nutrition_info.append(line)
    
    return {
        'dish_name': dish_name,
        'visible_ingredients': '\n'.join(visible_ingredients),
        'hidden_ingredients': '\n'.join(hidden_ingredients),
        'nutrition_info': '\n'.join(nutrition_info)
    }

def extract_dish_name(description):
    """Extract dish name from first line"""
    lines = description.strip().split('\n')
    return lines[0].strip().capitalize() if lines else "Unknown Dish"

# ---------- Main Analysis Function ----------
def full_image_analysis(image_path, user_id):
    try:
        # Get combined analysis from Gemini
        print("🤖 Starting Gemini analysis...")
        combined_response = analyze_image_with_gemini_combined(image_path)
        
        # Parse the response
        parsed = parse_combined_response(combined_response)
        
        dish_name = parsed['dish_name']
        visible = parsed['visible_ingredients']
        hidden = parsed['hidden_ingredients']
        nutrition = parsed['nutrition_info']
        
        # Convert image to base64
        print("🖼️ Processing images...")
        with open(image_path, "rb") as img_file:
            img_data = img_file.read()
            img_base64 = base64.b64encode(img_data).decode('utf-8')
        
        # Create thumbnail
        img = Image.open(image_path)
        # Resize maintaining aspect ratio
        img.thumbnail((300, 300), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=40)
        thumb_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
        
        print("💾 Saving to database...")
        meal_doc = {
            "user_id": user_id,
            "dish_prediction": dish_name,
            "image_full": img_base64,
            "image_thumb": thumb_base64,
            "image_description": visible,  # Store visible ingredients here
            "hidden_ingredients": hidden,
            "nutrition_info": nutrition,
            "saved_at": datetime.now().isoformat()
        }

        result = meals_collection.insert_one(meal_doc)
        print(f"✅ Saved meal with ID: {result.inserted_id}")

        # Return format expected by iOS app
        return {
            "dish_prediction": dish_name,
            "image_description": visible,  # iOS expects visible ingredients here
            "hidden_ingredients": hidden,
            "nutrition_info": nutrition
        }
        
    except Exception as e:
        print(f"❌ Analysis error: {str(e)}")
        import traceback
        traceback.print_exc()
        
        # Return a basic response so the app doesn't crash
        return {
            "dish_prediction": "Unable to analyze",
            "image_description": "Food item | 1 | serving | Analysis failed",
            "hidden_ingredients": "",
            "nutrition_info": "Calories | 200 | kcal | Estimated average"
        }