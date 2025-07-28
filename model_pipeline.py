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

# Analyze image
def full_image_analysis(enter your field):
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




# Search Recipe
def search_recipe(enter your field):
    #1. Convert the keyword to lowercase for case-insensitive matching.

    #2. Try to open the CSV file (default: ./recipes.csv, don't need to change).

    #3. Read the CSV file as a dictionary where each row maps column names to values.

    #4. Check if the CSV file has any headers (fieldnames).

    #5. If not, print a warning and return None.

    #6. Loop through each row (recipe) in the CSV to find the first matching recipe

    #7. If the CSV file is not found, print a message.

    #8. If any other error occurs, print the error.

    #9. If no matching recipe is found, return None.


    
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
