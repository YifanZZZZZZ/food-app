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
    """Single Gemini call for all analysis with retries and optimization"""
    combined_prompt = """
    Analyze this food image and provide comprehensive information.
    
    First line: Just the dish name (be specific but concise)
    
    Then provide these sections:
    
    VISIBLE INGREDIENTS:
    List each visible ingredient in format: Ingredient | Quantity | Unit | Reasoning
    Maximum 5 items
    
    HIDDEN INGREDIENTS:
    List likely hidden ingredients (oils, spices, sauces) in format: Ingredient | Quantity | Unit | Reasoning
    Maximum 5 items
    
    NUTRITION INFO:
    List nutrition per serving in format: Nutrient | Value | Unit | Reasoning
    Must include: Calories, Protein, Fat, Carbohydrates, Fiber, Sugar, Sodium
    
    Rules:
    - Quantity must be a number only (no ranges like 1-2)
    - Be specific and realistic
    - Skip background items or utensils
    - Keep it concise
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
                temperature=0.7,
                max_output_tokens=1000,
            )
            
            # Make the API call with timeout
            response = gemini_model.generate_content(
                [combined_prompt, {"mime_type": "image/jpeg", "data": image_data}],
                generation_config=generation_config,
                request_options={"timeout": 30}
            )
            
            # Clean up optimized image
            try:
                os.remove(optimized_path)
            except:
                pass
            
            print("✅ Gemini analysis successful")
            return response.text
            
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
                # Return fallback response
                print("⚠️ All retries failed, returning fallback response")
                return """Food Item
                
VISIBLE INGREDIENTS:
Food | 1 | serving | Unable to analyze

HIDDEN INGREDIENTS:
Seasoning | 1 | pinch | Estimated

NUTRITION INFO:
Calories | 200 | kcal | Estimated average
Protein | 10 | g | Estimated
Fat | 8 | g | Estimated
Carbohydrates | 25 | g | Estimated
Fiber | 2 | g | Estimated
Sugar | 5 | g | Estimated
Sodium | 300 | mg | Estimated"""

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
        
        # Ensure nutrition info always has calories
        if not nutrition or "Calories" not in nutrition:
            # Add default nutrition if missing
            default_nutrition = """Calories | 200 | kcal | Estimated
Protein | 10 | g | Estimated
Fat | 8 | g | Estimated
Carbohydrates | 25 | g | Estimated
Fiber | 2 | g | Estimated
Sugar | 5 | g | Estimated
Sodium | 300 | mg | Estimated"""
            nutrition = default_nutrition if not nutrition else nutrition + "\n" + default_nutrition
        
        print(f"📊 Analysis completed in {time.time() - start_time:.2f} seconds")
        
        # DON'T save to database here - let the iOS app handle saving
        # This prevents duplicates
        
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
            "nutrition_info": "Calories | 200 | kcal | Estimated average\nProtein | 10 | g | Estimated\nFat | 8 | g | Estimated\nCarbohydrates | 25 | g | Estimated"
        }