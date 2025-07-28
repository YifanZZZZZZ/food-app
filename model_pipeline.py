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
def full_image_analysis():
    


# Search Recipe
def search_recipe():



    
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
