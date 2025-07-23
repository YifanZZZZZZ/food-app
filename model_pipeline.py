from PIL import Image
import requests
import base64
import os
import re
import time
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
from io import BytesIO
import csv
from transformers import pipeline

# Load environment variables
load_dotenv()

# Load model
#classifier = pipeline(
#    "image-classification",
#    model="Shresthadev403/food-image-classification"
#)
HF_API_URL = "https://router.huggingface.co/hf-inference/models/nateraw/food"
HF_HEADERS = {
    "Authorization": f"Bearer {os.getenv('HF_TOKEN', 'None')}",
    "Content-Type": "image/jpeg"
}

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
    """Main function for image classification and recipe lookup using local model and CSV."""
    try:
        start_time = time.time()

        print(f"🤖 Starting image analysis for user: {user_id}")
        print(f"📸 Image: {image_path}")

        # Step 1: Classify the image and fetch recipe
        recipe_result = recipe_classification(image_path)

        if not recipe_result:
            raise Exception("Image classification or recipe lookup failed.")

        dish_name = recipe_result.get('Name', 'Unknown Dish')
        ingredients = recipe_result.get('Ingredients', [])
        nutrition = recipe_result.get('Nutrition', {})

        analysis_time = time.time() - start_time

        print(f"✅ Analysis completed in {analysis_time:.2f} seconds")
        print(f"📍 Dish: {dish_name}")
        print(f"📍 Ingredients count: {len(ingredients)}")

        # Return structured result
        return {
            'dish_name': dish_name,
            'ingredient_list': ingredients,
            'nutrition_facts': nutrition,
            'analysis_time': round(analysis_time, 2),
            'user_id': user_id,
            'analysis_status': 'success',
            'source': 'local_model_and_csv',
            'debug_info': {
                'ingredient_count': len(ingredients),
                'classifier_output': dish_name,
                'nutrition_fields': list(nutrition.keys())
            }
        }


    except Exception as e:
        print(f"❌ Full analysis error: {str(e)}")
        error_msg = str(e)
        return {
            'dish_name': None,
            'ingredient_list': [],
            'nutrition_facts': {},
            'analysis_time': 0,
            'user_id': user_id,
            'analysis_status': 'failure',
            'source': 'local_model_and_csv',
            'debug_info': {
                'error': error_msg
            }
        }


def search_recipe(keyword, filename='./recipes.csv'):
    """
    Search for the first recipe containing the keyword in its name (case-insensitive).
    Returns a dictionary of the recipe or None if not found.
    """
    keyword = keyword.lower()

    try:
        with open(filename, newline='', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            if not reader.fieldnames:
                print("The CSV file is empty.")
                return None

            for row in reader:
                if keyword in row.get('Name', '').lower():
                    return row  # Return the first match immediately

    except FileNotFoundError:
        print(f"File '{filename}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

    return None  # No match found or an error occurred

def recipe_classification(image_path):
    try:
        # --- Optimize image before classification ---
        image = Image.open(image_path)

        # Resize if too large
        max_size = (1024, 1024)
        image.thumbnail(max_size, Image.Resampling.LANCZOS)

        # Convert to RGB if needed
        if image.mode not in ('RGB', 'L'):
            image = image.convert('RGB')

        # Save optimized version
        optimized_path = image_path.replace('.png', '_opt.jpg') \
                                   .replace('.jpeg', '_opt.jpg') \
                                   .replace('.jpg', '_opt.jpg')
        image.save(optimized_path, 'JPEG', quality=85)

        # --- Classify via Hugging Face Inference API ---
        with open(optimized_path, "rb") as f:
            response = requests.post(HF_API_URL, headers=HF_HEADERS, data=f.read())
        
        try:
            os.remove(optimized_path)
        except:
            pass  # Clean up regardless of outcome

        if response.status_code != 200:
            print(f"❌ HF API error: {response.status_code} - {response.text}")
            return None

        result = response.json()
        if not result or not isinstance(result, list) or "label" not in result[0]:
            print(f"❌ Invalid classification result: {result}")
            return None

        predicted_food = result[0]["label"].replace("_", " ")
        print(f"🍽️ Predicted food: {predicted_food}")

        selected_recipe = search_recipe(predicted_food)
        if not selected_recipe:
            print("⚠️ No matching recipe found.")
            return None

        recipe_dictionary = {"Name": selected_recipe["Name"]}

        # Parse ingredients
        raw_ingredients = selected_recipe.get("RecipeIngredientParts", "")
        raw_ingredients = raw_ingredients[2:-1]  # Remove `c(` and `)`
        ingredients = [item.strip().strip('"') for item in raw_ingredients.split(",")]
        recipe_dictionary["Ingredients"] = ingredients

        # Parse nutrition
        nutrition_keys = [
            "Calories", "FatContent", "SaturatedFatContent", "CholesterolContent",
            "SodiumContent", "CarbohydrateContent", "FiberContent", "SugarContent", "ProteinContent"
        ]
        nutrition_directory = {}
        for key in nutrition_keys:
            try:
                nutrition_directory[key] = float(selected_recipe[key])
            except (ValueError, TypeError, KeyError):
                nutrition_directory[key] = None
        recipe_dictionary["Nutrition"] = nutrition_directory

        print("📋 Recipe Info:")
        print(recipe_dictionary)
        return recipe_dictionary

    except Exception as e:
        print(f"❌ Could not process image {image_path}: {e}")
        return None

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
