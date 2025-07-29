from PIL import Image
import requests
import json
import logging
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
from transformers import AutoFeatureExtractor, AutoModelForImageClassification


# Load environment variables
load_dotenv()

# Load model inference
API_URL = "https://router.huggingface.co/hf-inference/models/nateraw/food"
headers = {
    "Authorization": f"Bearer {os.getenv('HF_TOKEN')}",
}

def query(filename):
    with open(filename, "rb") as f:
        data = f.read()
    response = requests.post(API_URL, headers={"Content-Type": "image/jpeg", **headers}, data=data)
    return response.json()

output = query("/content/pasta.png")
print(output)

model_name = "nateraw/food"
processor = AutoFeatureExtractor.from_pretrained(model_name)
model = AutoModelForImageClassification.from_pretrained(model_name)

# MongoDB Setup
# os.getenv goes back to the environment variables
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

# Analyze image
# def full_image_analysis(): #enter your field
#     print("Nothing in full_image_analysis()")
#     search_recipe()
    #1. Start a timer to measure total analysis time.

    #2. Print the user ID and image path for debugging.

    #3. Open the uploaded image.

    #4. Convert the image to RGB if it's in another color mode.

    #5. Save a temporary optimized version of the image in JPEG format.

    #6. Send the optimized image to the Hugging Face classification API.

    #7. Delete the temporary optimized image to clean up.

    #8. Validate the API response code to ensure it contains a label.

    #9. Extract the predicted food name from the API response.

    #10. Search for a matching recipe using the predicted food name.

    #11. Parse the ingredient list from the recipe data and add it to a directory. 

    #12. Parse nutrition fields like calories, fat, protein, etc, and add it to a directory.

    #13. Calculate how long the analysis took.

    #14. Print debug information: dish name, ingredients, nutrition.

    #15. Return a structured result dictionary containing: dish name, ingredients, nutrition facts, analysis time, status, and debug info

    #16. If any error occurs, catch it and return a failure response with error info.

import traceback

def full_image_analysis(user_id=None, image_path=None):
    start_time = time.time()
    debug_info = {}
    try:
        debug_info['user_id'] = user_id
        debug_info['image_path'] = image_path

        # Validate image
        valid, msg = validate_image_for_analysis(image_path)
        if not valid:
            return {
                "status": "failure",
                "error": msg,
                "analysis_time": 0,
                "debug_info": debug_info
            }

        # Open and preprocess image
        with Image.open(image_path) as img:
            img = img.convert("RGB")
            temp_path = "temp_optimized.jpg"
            img.save(temp_path, format="JPEG", optimize=True, quality=85)

        # Preprocess and run inference
        inputs = processor(images=Image.open(temp_path), return_tensors="pt")
        outputs = model(**inputs)
        logits = outputs.logits
        predicted_class_idx = logits.argmax(-1).item()
        label = model.config.id2label[predicted_class_idx]
        debug_info['predicted_label'] = label

        # Clean up temp image
        os.remove(temp_path)

        # Search for recipe
        recipe = search_recipe(label)
        if not recipe:
            return {
                "status": "failure",
                "error": "No matching recipe found",
                "analysis_time": round(time.time() - start_time, 2),
                "debug_info": debug_info
            }

        # Parse ingredients and nutrition
        ingredients = parse_to_dict(recipe.get("ingredients", ""))
        nutrition = parse_to_dict(recipe.get("nutrition", ""))

        analysis_time = round(time.time() - start_time, 2)
        debug_info['ingredients'] = ingredients
        debug_info['nutrition'] = nutrition

        return {
            "status": "success",
            "dish_name": label,
            "ingredients": ingredients,
            "nutrition": nutrition,
            "analysis_time": analysis_time,
            "debug_info": debug_info
        }

    except Exception as e:
        return {
            "status": "failure",
            "error": str(e),
            "traceback": traceback.format_exc(),
            "analysis_time": round(time.time() - start_time, 2),
            "debug_info": debug_info
        }




# Search Recipe
# def search_recipe(): #enter your field
#     print("Nothing in search_recipe()")
    #1. Convert the keyword to lowercase for case-insensitive matching.

    #2. Try to open the CSV file (default: ./recipes.csv, don't need to change).

    #3. Read the CSV file as a dictionary where each row maps column names to values.

    #4. Check if the CSV file has any headers (fieldnames).

    #5. If not, print a warning and return None.

    #6. Loop through each row (recipe) in the CSV to find the first matching recipe

    #7. If the CSV file is not found, print a message.

    #8. If any other error occurs, print the error.

    #9. If no matching recipe is found, return None.

def search_recipe(keyword, csv_path="./recipes.csv"):
    """Search for a recipe by keyword in the CSV file."""
    keyword = keyword.lower()
    if not os.path.exists(csv_path):
        print(f"CSV file not found: {csv_path}")
        return None

    try:
        with open(csv_path, newline='', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            if not reader.fieldnames:
                print("CSV file has no headers.")
                return None

            for row in reader:
                # Assuming 'name' is the column for recipe name
                if row.get("name", "").lower() == keyword:
                    return row

        # No matching recipe found
        return None

    except Exception as e:
        print(f"Error reading CSV: {e}")
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
