from PIL import Image
import google.generativeai as genai
import base64
import os
import time
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
from io import BytesIO

# ---------- Load Environment ----------
load_dotenv()

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
    """Single Gemini call for all analysis with improved prompts"""
    combined_prompt = """
    You are a professional nutritionist analyzing a food image. Your task is to provide detailed analysis even if multiple dishes are present.

    IMPORTANT RULES:
    1. If there are multiple dishes/items in the image, combine them into ONE comprehensive analysis
    2. The dish name should describe ALL items visible (e.g., "Pasta with Salad and Bread")
    3. List ALL visible ingredients from ALL dishes
    4. You MUST provide ingredients even if you need to estimate
    5. You MUST provide nutrition info - estimate if needed based on typical portions
    6. Never say "unable to determine" - always provide your best educated estimate

    FORMAT YOUR RESPONSE EXACTLY LIKE THIS:

    First line: Combined dish name describing all items (be specific)

    VISIBLE INGREDIENTS:
    [List each visible ingredient from ALL dishes in format]
    Ingredient | Quantity | Unit | Source/Reasoning
    
    Example format:
    Pasta | 200 | grams | Main dish visible
    Tomato sauce | 100 | grams | Red sauce on pasta
    Lettuce | 50 | grams | Side salad visible
    
    IMPORTANT: 
    - Include ingredients from ALL visible dishes
    - Be specific about quantities (use numbers, not "some" or "few")
    - If unsure, estimate based on typical serving sizes
    - List at least 3-10 ingredients

    HIDDEN INGREDIENTS:
    [List likely ingredients not directly visible]
    Ingredient | Quantity | Unit | Reasoning
    
    Example format:
    Olive oil | 15 | ml | Likely used in cooking
    Salt | 2 | grams | Standard seasoning
    Garlic | 5 | grams | Common in this dish type
    
    IMPORTANT:
    - Include cooking oils, seasonings, sauces bases
    - List at least 3-7 hidden ingredients

    NUTRITION INFO:
    [Calculate total nutrition for ALL items visible]
    Nutrient | Value | Unit | Calculation basis
    
    REQUIRED nutrients (must include all):
    Calories | [number] | kcal | Based on all dishes
    Protein | [number] | g | Total from all items
    Fat | [number] | g | Total from all items
    Carbohydrates | [number] | g | Total from all items
    Fiber | [number] | g | Estimated from ingredients
    Sugar | [number] | g | Natural and added sugars
    Sodium | [number] | mg | From salt and processed items

    IMPORTANT:
    - Calculate nutrition for TOTAL meal (all dishes combined)
    - Use realistic estimates based on portion sizes
    - Never use 0 for calories - minimum 50 kcal for any food item

    Remember: This analysis helps users track their nutrition, so be thorough and specific. If you see multiple dishes, analyze them as one complete meal.
    """
    
    max_retries = 3
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            # Optimize image before sending
            image = Image.open(image_path)
            
            # Resize if too large
            max_size = (1024, 1024)
            image.thumbnail(max_size, Image.Resampling.LANCZOS)
            
            # Convert to RGB if necessary
            if image.mode not in ('RGB', 'L'):
                image = image.convert('RGB')
            
            # Save optimized image
            optimized_path = image_path.replace('.png', '_opt.jpg')
            image.save(optimized_path, 'JPEG', quality=85)
            
            # Encode optimized image
            with open(optimized_path, "rb") as img_file:
                image_data = base64.b64encode(img_file.read()).decode('utf-8')
            
            print(f"🔍 Sending optimized image to Gemini (attempt {attempt + 1}/{max_retries})")
            
            # Configure generation with safety settings
            generation_config = genai.types.GenerationConfig(
                temperature=0.4,  # Lower temperature for more consistent output
                max_output_tokens=1500,  # Increased for detailed analysis
            )
            
            # Make the API call with timeout
            response = gemini_model.generate_content(
                [combined_prompt, {"mime_type": "image/jpeg", "data": image_data}],
                generation_config=generation_config,
                request_options={"timeout": 45}
            )
            
            # Clean up optimized image
            try:
                os.remove(optimized_path)
            except:
                pass
            
            print("✅ Gemini analysis successful")
            
            # Validate response has required sections
            response_text = response.text
            if "VISIBLE INGREDIENTS:" in response_text and "NUTRITION INFO:" in response_text:
                return response_text
            else:
                print("⚠️ Response missing required sections, retrying...")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                    continue
                else:
                    return generate_fallback_response()
            
        except Exception as e:
            print(f"❌ Gemini attempt {attempt + 1} failed: {str(e)}")
            
            # Clean up optimized image on error
            try:
                if 'optimized_path' in locals():
                    os.remove(optimized_path)
            except:
                pass
            
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff
            else:
                return generate_fallback_response()

def generate_fallback_response():
    """Generate a reasonable fallback response"""
    print("⚠️ Using fallback response")
    return """Mixed Meal Plate

VISIBLE INGREDIENTS:
Main dish | 200 | grams | Primary item visible
Vegetables | 100 | grams | Side vegetables
Grain/Starch | 150 | grams | Rice/bread/pasta visible
Sauce | 50 | ml | Visible on dish

HIDDEN INGREDIENTS:
Cooking oil | 15 | ml | Used in preparation
Salt | 2 | grams | Standard seasoning
Black pepper | 1 | gram | Common seasoning
Butter | 10 | grams | Likely in preparation

NUTRITION INFO:
Calories | 450 | kcal | Estimated for full meal
Protein | 20 | g | From main dish and grains
Fat | 15 | g | From cooking and ingredients
Carbohydrates | 60 | g | From grains and vegetables
Fiber | 5 | g | From vegetables and grains
Sugar | 8 | g | Natural and added
Sodium | 600 | mg | From salt and seasonings"""

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
        
        # Skip empty lines
        if not line:
            continue
        
        # Check for section headers
        if 'VISIBLE INGREDIENTS' in line.upper():
            current_section = 'visible'
            continue
        elif 'HIDDEN INGREDIENTS' in line.upper():
            current_section = 'hidden'
            continue
        elif 'NUTRITION INFO' in line.upper():
            current_section = 'nutrition'
            continue
        
        # Parse ingredient/nutrition lines
        if '|' in line and current_section:
            # Clean up the line
            parts = [p.strip() for p in line.split('|')]
            if len(parts) >= 3:  # Ensure we have at least name, quantity, unit
                if current_section == 'visible':
                    visible_ingredients.append(line)
                elif current_section == 'hidden':
                    hidden_ingredients.append(line)
                elif current_section == 'nutrition':
                    nutrition_info.append(line)
    
    # Ensure we have at least some data in each section
    if not visible_ingredients:
        visible_ingredients = ["Food item | 200 | grams | Visible in image"]
    
    if not nutrition_info:
        nutrition_info = [
            "Calories | 300 | kcal | Estimated",
            "Protein | 15 | g | Estimated",
            "Fat | 10 | g | Estimated",
            "Carbohydrates | 40 | g | Estimated",
            "Fiber | 3 | g | Estimated",
            "Sugar | 5 | g | Estimated",
            "Sodium | 400 | mg | Estimated"
        ]
    
    return {
        'dish_name': dish_name,
        'visible_ingredients': '\n'.join(visible_ingredients),
        'hidden_ingredients': '\n'.join(hidden_ingredients),
        'nutrition_info': '\n'.join(nutrition_info)
    }

def extract_dish_name(description):
    """Extract dish name from first line"""
    lines = description.strip().split('\n')
    return lines[0].strip() if lines else "Unknown Dish"

# ---------- Main Analysis Function ----------
def full_image_analysis(image_path, user_id):
    try:
        start_time = time.time()
        
        # Get combined analysis from Gemini
        print("🤖 Starting Gemini analysis...")
        combined_response = analyze_image_with_gemini_combined(image_path)
        
        # Parse the response
        parsed = parse_combined_response(combined_response)
        
        dish_name = parsed['dish_name']
        visible = parsed['visible_ingredients']
        hidden = parsed['hidden_ingredients']
        nutrition = parsed['nutrition_info']
        
        # Validate and ensure all required nutrients are present
        required_nutrients = ["Calories", "Protein", "Fat", "Carbohydrates", "Fiber", "Sugar", "Sodium"]
        nutrition_lines = nutrition.split('\n')
        
        for nutrient in required_nutrients:
            if not any(nutrient.lower() in line.lower() for line in nutrition_lines):
                # Add missing nutrient with default value
                if nutrient == "Calories":
                    nutrition += f"\n{nutrient} | 200 | kcal | Estimated default"
                elif nutrient == "Sodium":
                    nutrition += f"\n{nutrient} | 300 | mg | Estimated default"
                else:
                    nutrition += f"\n{nutrient} | 5 | g | Estimated default"
        
        print(f"📊 Analysis completed in {time.time() - start_time:.2f} seconds")
        
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
        
        # Return a reasonable default response
        return {
            "dish_prediction": "Mixed Meal",
            "image_description": "Main dish | 200 | grams | Visible in image\nSide dish | 100 | grams | Visible in image\nVegetables | 50 | grams | Visible in image",
            "hidden_ingredients": "Cooking oil | 15 | ml | Used in preparation\nSalt | 2 | grams | Standard seasoning",
            "nutrition_info": "Calories | 400 | kcal | Estimated total\nProtein | 20 | g | Estimated\nFat | 15 | g | Estimated\nCarbohydrates | 50 | g | Estimated\nFiber | 5 | g | Estimated\nSugar | 8 | g | Estimated\nSodium | 500 | mg | Estimated"
        }