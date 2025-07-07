from PIL import Image
import google.generativeai as genai
import base64
import os
import re
import time
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
from io import BytesIO

# Load environment variables
load_dotenv()

# Gemini API Setup
GEN_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEN_API_KEY:
    raise ValueError("GEMINI_API_KEY is not set in environment variables.")

genai.configure(api_key=GEN_API_KEY)
gemini_model = genai.GenerativeModel('gemini-1.5-flash')

# MongoDB Setup
mongo_uri = os.getenv("MONGO_URI")
mongo_db = os.getenv("MONGO_DB", "food-app-swift")
client = MongoClient(mongo_uri)
db = client[mongo_db]
meals_collection = db["meals"]

def encode_image(image_path):
    """Encode image to base64"""
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode("utf-8")

def analyze_image_with_gemini(image_path):
    """Analyze image with Gemini - based on working web app code"""
    try:
        # Optimize image before sending
        image = Image.open(image_path)
        
        # Resize if too large
        max_size = (1024, 1024)
        image.thumbnail(max_size, Image.Resampling.LANCZOS)
        
        # Convert to RGB if needed
        if image.mode not in ('RGB', 'L'):
            image = image.convert('RGB')
        
        # Save optimized version
        optimized_path = image_path.replace('.png', '_opt.jpg')
        image.save(optimized_path, 'JPEG', quality=85)
        
        # Encode optimized image
        image_data = encode_image(optimized_path)
        
        # Clean up optimized file
        try:
            os.remove(optimized_path)
        except:
            pass
        
        # Proven prompt from working web app
        prompt = (
            "Describe the food dish in this image.\n"
            "Return the dish name on the first line.\n"
            "Then list each visible ingredient on a new line in the format: Ingredient | Quantity Number | Unit | Reasoning.\n"
            "Quantity Number must be a numeric value only.\n"
            "Avoid vague ranges or approximations like 'a few' or 'some'.\n"
            "Be concise and avoid unnecessary descriptions.\n"
            "Skip any background or utensils."
        )
        
        print("🔍 Analyzing image with Gemini...")
        
        response = gemini_model.generate_content([
            prompt,
            {"mime_type": "image/jpeg", "data": image_data}
        ])
        
        if response and response.text:
            print("✅ Gemini analysis successful")
            return response.text
        else:
            raise Exception("Empty response from Gemini")
            
    except Exception as e:
        print(f"❌ Gemini analysis error: {str(e)}")
        return f"Gemini error: {str(e)}"

def extract_ingredients_only(description):
    """Extract only ingredient lines from description"""
    lines = description.splitlines()
    ingredients = []
    for line in lines[1:]:  # Skip first line (dish name)
        if '|' in line and len(line.split('|')) == 4:
            ingredients.append(line.strip())
    return "\n".join(ingredients)

def search_hidden_ingredients(dish_name, visible_ingredients):
    """Find hidden ingredients based on dish name and visible ingredients"""
    prompt = (
        f"You are a recipe analyst.\n"
        f"For the dish '{dish_name}', given the following visible ingredients:\n{visible_ingredients},\n"
        "list only the likely hidden ingredients used in traditional or common recipes for this dish.\n"
        "Format each hidden ingredient on a new line like this: Ingredient | Quantity Number | Unit | Reasoning.\n"
        "Quantity Number must be a numeric value only.\n"
        "Only include core items like oil, butter, sauces, or spices typically used. Avoid optional or garnish ingredients.\n"
        "Do NOT use any vague descriptions. Be clear and formatted strictly."
    )
    
    try:
        print("🔍 Searching for hidden ingredients...")
        response = gemini_model.generate_content(prompt)
        
        if response and response.text:
            print("✅ Hidden ingredients found")
            return response.text
        else:
            return "No hidden ingredients identified"
            
    except Exception as e:
        print(f"❌ Hidden ingredients error: {str(e)}")
        return f"Hidden ingredients lookup error: {str(e)}"

def estimate_nutrition_from_ingredients(dish_name, visible_ingredients):
    """Estimate nutrition based on ingredients"""
    prompt = (
        f"You are a nutritionist.\n"
        f"The user has provided the visible ingredients from a dish named '{dish_name}'.\n"
        f"Ingredients:\n{visible_ingredients}\n\n"
        "Your task is to output the nutritional breakdown per serving (based on image analysis).\n"
        "Output each nutrient on a new line in this exact format:\n"
        "Nutrient | Value | Unit | Reasoning\n"
        "Value must be a numeric value only.\n"
        "Example:\n"
        "Calories | 720 | kcal | Estimated from rice and cheese.\n"
        "Protein | 32 | g | Chicken and beans contribute majorly.\n\n"
        "Avoid ranges (like 100–200) or vague statements.\n"
        "Include at least these nutrients: Calories, Protein, Fat, Carbohydrates, Fiber, Sugar, Sodium.\n"
        "Be strict with the format."
    )
    
    try:
        print("🔍 Estimating nutrition...")
        response = gemini_model.generate_content(prompt)
        
        if response and response.text:
            print("✅ Nutrition estimation complete")
            return response.text
        else:
            return "Nutrition estimation failed"
            
    except Exception as e:
        print(f"❌ Nutrition estimation error: {str(e)}")
        return f"Nutrition estimation error: {str(e)}"

def extract_dish_name(description):
    """Extract dish name from description"""
    # Look for explicit dish name pattern
    match = re.search(r'(?i)(?:dish name[:\-]?)\s*(.*)', description)
    if match:
        return match.group(1).strip().capitalize()
    
    # Otherwise use first line
    first_line = description.strip().split('\n')[0]
    return first_line.strip().capitalize()

def parse_to_dict(text):
    """Parse formatted text to dictionary"""
    data_dict = {}
    for line in text.splitlines():
        parts = [p.strip() for p in line.split('|')]
        if len(parts) == 4:
            try:
                # Try to convert to numeric value
                numeric_value = float(parts[1]) if '.' in parts[1] else int(parts[1])
                data_dict[parts[0]] = {
                    "Quantity Number/Value": numeric_value,
                    "Unit": parts[2],
                    "Reasoning": parts[3]
                }
            except ValueError:
                continue
    return data_dict

def full_image_analysis(image_path, user_id):
    """Main function for complete image analysis - based on working web app"""
    try:
        start_time = time.time()
        
        print(f"🤖 Starting image analysis for user: {user_id}")
        print(f"📸 Image: {image_path}")
        
        # Step 1: Get basic description and dish name
        gemini_description = analyze_image_with_gemini(image_path)
        
        if "Gemini error" in gemini_description:
            raise Exception(f"Gemini analysis failed: {gemini_description}")
        
        # Step 2: Extract dish name
        dish_name = extract_dish_name(gemini_description)
        
        # Step 3: Extract clean ingredients list
        cleaned_ingredients = extract_ingredients_only(gemini_description)
        
        if not cleaned_ingredients:
            raise Exception("No ingredients could be identified from the image")
        
        # Step 4: Find hidden ingredients
        hidden_ingredients = search_hidden_ingredients(dish_name, cleaned_ingredients)
        
        # Step 5: Estimate nutrition
        nutrition_info = estimate_nutrition_from_ingredients(dish_name, cleaned_ingredients)
        
        # Step 6: Parse data for potential storage
        visible_dict = parse_to_dict(cleaned_ingredients)
        hidden_dict = parse_to_dict(hidden_ingredients)
        
        analysis_time = time.time() - start_time
        
        print(f"✅ Analysis completed in {analysis_time:.2f} seconds")
        print(f"📍 Dish: {dish_name}")
        print(f"📍 Visible ingredients: {len(visible_dict)} items")
        print(f"📍 Hidden ingredients: {len(hidden_dict)} items")
        
        # Return in format expected by Swift frontend
        return {
            'dish_prediction': dish_name,
            'image_description': cleaned_ingredients,
            'hidden_ingredients': hidden_ingredients,
            'nutrition_info': nutrition_info,
            'analysis_time': analysis_time,
            'user_id': user_id
        }
        
    except Exception as e:
        print(f"❌ Full analysis error: {str(e)}")
        
        # Return error response
        error_msg = str(e)
        return {
            'dish_prediction': f"Analysis failed: {error_msg}",
            'image_description': f"Could not identify ingredients | 0 | g | {error_msg}",
            'hidden_ingredients': f"Could not identify | 0 | g | {error_msg}",
            'nutrition_info': f"Calories | 0 | kcal | Analysis failed\nProtein | 0 | g | Analysis failed\nFat | 0 | g | Analysis failed\nCarbohydrates | 0 | g | Analysis failed\nFiber | 0 | g | Analysis failed\nSugar | 0 | g | Analysis failed\nSodium | 0 | mg | Analysis failed",
            'analysis_time': 0,
            'user_id': user_id,
            'error': error_msg
        }

def recalculate_nutrition_enhanced(ingredients_text):
    """Recalculate nutrition based on modified ingredients"""
    try:
        print(f"🔄 Recalculating nutrition...")
        
        prompt = (
            f"You are a nutritionist.\n"
            f"Calculate the exact nutritional values for these ingredients:\n\n{ingredients_text}\n\n"
            "Output each nutrient on a new line in this exact format:\n"
            "Nutrient | Value | Unit | Reasoning\n"
            "Value must be a numeric value only.\n"
            "Include at least: Calories, Protein, Fat, Carbohydrates, Fiber, Sugar, Sodium.\n"
            "Base calculations on the specific quantities provided.\n"
            "Be strict with the format."
        )
        
        response = gemini_model.generate_content(prompt)
        
        if response and response.text:
            print("✅ Nutrition recalculated successfully")
            return response.text
        else:
            raise Exception("Empty response from Gemini")
            
    except Exception as e:
        print(f"❌ Nutrition recalculation error: {str(e)}")
        error_msg = str(e)
        return f"Calories | 0 | kcal | Recalculation failed: {error_msg}\nProtein | 0 | g | Recalculation failed: {error_msg}\nFat | 0 | g | Recalculation failed: {error_msg}\nCarbohydrates | 0 | g | Recalculation failed: {error_msg}\nFiber | 0 | g | Recalculation failed: {error_msg}\nSugar | 0 | g | Recalculation failed: {error_msg}\nSodium | 0 | mg | Recalculation failed: {error_msg}"

def validate_image_for_analysis(image_path):
    """Validate image before analysis"""
    try:
        with Image.open(image_path) as img:
            # Check minimum size
            if img.width < 100 or img.height < 100:
                return False, "Image too small for analysis"
            
            # Check format
            if img.format not in ['JPEG', 'PNG', 'WEBP']:
                return False, f"Unsupported format: {img.format}"
            
            return True, "Image is valid"
            
    except Exception as e:
        return False, f"Invalid image: {str(e)}"