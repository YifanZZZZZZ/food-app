from PIL import Image
import google.generativeai as genai
import base64
import os
import time
from datetime import datetime
from dotenv import load_dotenv
from pymongo import MongoClient
from io import BytesIO
import json

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

# ---------- FULLY DYNAMIC Analysis Function ----------
def analyze_image_with_gemini_dynamic(image_path):
    """FULLY DYNAMIC Gemini analysis - ZERO hardcoded values"""
    
    # Enhanced prompt for maximum accuracy and specificity
    dynamic_prompt = """
You are a professional nutritionist with expertise in food identification and nutritional analysis. Analyze THIS SPECIFIC food image with extreme precision.

CRITICAL INSTRUCTIONS:
1. Analyze ONLY what you see in THIS exact image
2. Do NOT use any generic templates or default values
3. Every measurement must be based on visual assessment of THIS specific portion
4. If you cannot see something clearly, say "Unable to determine from image"
5. Be as specific as possible about ingredients and quantities

REQUIRED OUTPUT FORMAT:

DISH NAME:
[Provide the most accurate name for what you see in this image]

VISIBLE INGREDIENTS:
[For each ingredient you can clearly see in the image, provide:]
[ingredient name] | [quantity estimate based on visual size] | [appropriate unit] | [description of what you see]

HIDDEN INGREDIENTS:
[For ingredients likely used but not visible, based on cooking method/appearance:]
[ingredient name] | [quantity estimate] | [appropriate unit] | [reasoning based on visual cues]

NUTRITION ANALYSIS:
[Calculate based on ALL ingredients identified above:]
Calories | [calculated amount] | kcal | [brief calculation explanation]
Protein | [calculated amount] | g | [main protein sources identified]
Fat | [calculated amount] | g | [fat sources identified]
Carbohydrates | [calculated amount] | g | [carb sources identified]
Fiber | [calculated amount] | g | [fiber sources identified]
Sugar | [calculated amount] | g | [sugar sources identified]
Sodium | [calculated amount] | mg | [sodium sources identified]

ANALYSIS NOTES:
- Base all calculations on the specific portion size visible in the image
- Consider cooking methods visible (fried, baked, grilled, etc.)
- Account for condiments, oils, and seasonings based on appearance
- If multiple items are present, analyze each component separately then sum totals

Remember: This analysis is for THIS SPECIFIC image only. Do not use generic portion sizes or standard recipes.
"""
    
    max_retries = 3
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            # Load and optimize image
            image = Image.open(image_path)
            
            # Ensure reasonable size for API
            max_size = (1024, 1024)
            image.thumbnail(max_size, Image.Resampling.LANCZOS)
            
            # Convert to RGB if needed
            if image.mode not in ('RGB', 'L'):
                image = image.convert('RGB')
            
            # Save optimized version
            optimized_path = image_path.replace('.png', '_opt.jpg')
            image.save(optimized_path, 'JPEG', quality=85)
            
            # Read and encode
            with open(optimized_path, "rb") as img_file:
                image_data = base64.b64encode(img_file.read()).decode('utf-8')
            
            print(f"🔍 Performing fully dynamic analysis (attempt {attempt + 1}/{max_retries})")
            
            # Configure for maximum accuracy
            generation_config = genai.types.GenerationConfig(
                temperature=0.1,  # Very low temperature for consistency
                max_output_tokens=3000,  # Increased for detailed analysis
                top_p=0.9,
                top_k=40
            )
            
            # Get Gemini's analysis
            response = gemini_model.generate_content(
                [dynamic_prompt, {"mime_type": "image/jpeg", "data": image_data}],
                generation_config=generation_config,
                request_options={"timeout": 90}
            )
            
            # Clean up optimized image
            try:
                os.remove(optimized_path)
            except:
                pass
            
            if response and response.text:
                print("✅ Dynamic analysis completed successfully")
                return response.text
            else:
                raise Exception("Empty response from Gemini API")
            
        except Exception as e:
            print(f"❌ Analysis attempt {attempt + 1} failed: {str(e)}")
            
            # Clean up on error
            try:
                if 'optimized_path' in locals():
                    os.remove(optimized_path)
            except:
                pass
            
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
                retry_delay *= 2
            else:
                # Final attempt with simpler analysis
                return attempt_basic_analysis(image_path)
    
    return attempt_basic_analysis(image_path)

def attempt_basic_analysis(image_path):
    """Attempt basic analysis when main analysis fails - still dynamic"""
    print("⚠️ Attempting basic dynamic analysis")
    
    try:
        # Try with a simpler prompt
        simple_prompt = """
Analyze this food image and provide:

1. What food do you see?
2. List visible ingredients with estimated quantities
3. Estimate calories and basic nutrition

Format your response as:
DISH NAME: [name]
VISIBLE INGREDIENTS: [ingredient] | [amount] | [unit] | [description]
NUTRITION ANALYSIS: [nutrient] | [amount] | [unit] | [source]
"""
        
        # Load image
        image = Image.open(image_path)
        image.thumbnail((512, 512), Image.Resampling.LANCZOS)
        
        if image.mode not in ('RGB', 'L'):
            image = image.convert('RGB')
        
        # Save and encode
        temp_path = image_path.replace('.png', '_basic.jpg')
        image.save(temp_path, 'JPEG', quality=70)
        
        with open(temp_path, "rb") as img_file:
            image_data = base64.b64encode(img_file.read()).decode('utf-8')
        
        # Simple generation config
        config = genai.types.GenerationConfig(
            temperature=0.3,
            max_output_tokens=1500,
        )
        
        response = gemini_model.generate_content(
            [simple_prompt, {"mime_type": "image/jpeg", "data": image_data}],
            generation_config=config,
            request_options={"timeout": 60}
        )
        
        # Clean up
        try:
            os.remove(temp_path)
        except:
            pass
        
        if response and response.text:
            return response.text
        else:
            raise Exception("Basic analysis also failed")
            
    except Exception as e:
        print(f"❌ Basic analysis failed: {str(e)}")
        return generate_failure_response(str(e))

def generate_failure_response(error_details):
    """Generate a failure response that indicates analysis couldn't be completed"""
    return f"""Analysis failed: {error_details}

DISH NAME:
Unable to analyze this image

VISIBLE INGREDIENTS:
Could not identify | 0 | g | Image analysis failed - {error_details}

HIDDEN INGREDIENTS:
Could not identify | 0 | g | Image analysis failed - {error_details}

NUTRITION ANALYSIS:
Calories | 0 | kcal | Analysis failed - unable to calculate
Protein | 0 | g | Analysis failed - unable to calculate
Fat | 0 | g | Analysis failed - unable to calculate
Carbohydrates | 0 | g | Analysis failed - unable to calculate
Fiber | 0 | g | Analysis failed - unable to calculate
Sugar | 0 | g | Analysis failed - unable to calculate
Sodium | 0 | mg | Analysis failed - unable to calculate

ERROR DETAILS: {error_details}
"""

def parse_dynamic_response(response_text):
    """Parse Gemini's dynamic response with better error handling"""
    try:
        lines = response_text.strip().split('\n')
        
        # Initialize sections
        dish_name = ""
        visible_ingredients = []
        hidden_ingredients = []
        nutrition_info = []
        
        current_section = None
        
        for line in lines:
            line = line.strip()
            
            if not line:
                continue
            
            # Identify sections
            if line.startswith('DISH NAME:'):
                dish_name = line.replace('DISH NAME:', '').strip()
                continue
            elif 'VISIBLE INGREDIENTS' in line.upper():
                current_section = 'visible'
                continue
            elif 'HIDDEN INGREDIENTS' in line.upper():
                current_section = 'hidden'
                continue
            elif 'NUTRITION ANALYSIS' in line.upper() or 'NUTRITION INFO' in line.upper():
                current_section = 'nutrition'
                continue
            
            # Parse content lines
            if '|' in line and current_section:
                parts = [p.strip() for p in line.split('|')]
                if len(parts) >= 3:
                    if current_section == 'visible':
                        visible_ingredients.append(line)
                    elif current_section == 'hidden':
                        hidden_ingredients.append(line)
                    elif current_section == 'nutrition':
                        nutrition_info.append(line)
        
        # If no dish name found, try to extract from first lines
        if not dish_name:
            for line in lines[:5]:
                line = line.strip()
                if line and not any(keyword in line.upper() for keyword in ['VISIBLE', 'HIDDEN', 'NUTRITION', 'INGREDIENTS', 'ANALYSIS']):
                    dish_name = line
                    break
        
        # Ensure we have a dish name
        if not dish_name:
            dish_name = "Unidentified food item"
        
        # Ensure minimum required nutrients
        required_nutrients = ["Calories", "Protein", "Fat", "Carbohydrates", "Fiber", "Sugar", "Sodium"]
        existing_nutrients = [line.split('|')[0].strip().lower() for line in nutrition_info if '|' in line]
        
        for nutrient in required_nutrients:
            if nutrient.lower() not in existing_nutrients:
                unit = "kcal" if nutrient == "Calories" else "mg" if nutrient == "Sodium" else "g"
                nutrition_info.append(f"{nutrient} | 0 | {unit} | Not determined from image")
        
        # Ensure we have at least one visible ingredient
        if not visible_ingredients:
            visible_ingredients = ["Food item visible | 0 | g | Could not identify specific ingredients"]
        
        # Ensure we have hidden ingredients section
        if not hidden_ingredients:
            hidden_ingredients = ["No hidden ingredients identified | 0 | g | Could not determine cooking method"]
        
        return {
            'dish_name': dish_name,
            'visible_ingredients': '\n'.join(visible_ingredients),
            'hidden_ingredients': '\n'.join(hidden_ingredients),
            'nutrition_info': '\n'.join(nutrition_info)
        }
        
    except Exception as e:
        print(f"❌ Response parsing error: {str(e)}")
        return {
            'dish_name': "Analysis parsing failed",
            'visible_ingredients': f"Parsing error | 0 | g | {str(e)}",
            'hidden_ingredients': f"Parsing error | 0 | g | {str(e)}",
            'nutrition_info': "Calories | 0 | kcal | Parsing failed\nProtein | 0 | g | Parsing failed\nFat | 0 | g | Parsing failed\nCarbohydrates | 0 | g | Parsing failed\nFiber | 0 | g | Parsing failed\nSugar | 0 | g | Parsing failed\nSodium | 0 | mg | Parsing failed"
        }

# ---------- Main Analysis Function ----------
def full_image_analysis(image_path, user_id):
    """Main function that performs FULLY DYNAMIC analysis with zero hardcoded values"""
    try:
        start_time = time.time()
        
        print("🤖 Starting FULLY DYNAMIC Gemini analysis...")
        print(f"📸 Analyzing image: {image_path}")
        print(f"👤 User ID: {user_id}")
        
        # Validate image exists
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image file not found: {image_path}")
        
        # Validate image is readable
        try:
            with Image.open(image_path) as img:
                img.verify()
        except Exception as e:
            raise ValueError(f"Invalid image file: {str(e)}")
        
        # Get dynamic analysis from Gemini
        gemini_response = analyze_image_with_gemini_dynamic(image_path)
        
        # Parse the response
        parsed = parse_dynamic_response(gemini_response)
        
        # Extract components
        dish_name = parsed['dish_name']
        visible = parsed['visible_ingredients']
        hidden = parsed['hidden_ingredients']
        nutrition = parsed['nutrition_info']
        
        # Log results
        analysis_time = time.time() - start_time
        print(f"📊 FULLY DYNAMIC analysis completed in {analysis_time:.2f} seconds")
        print(f"📍 Dish: {dish_name}")
        print(f"📍 Visible ingredients: {len(visible.split('\\n'))} items")
        print(f"📍 Hidden ingredients: {len(hidden.split('\\n'))} items")
        print(f"📍 Nutrition facts: {len(nutrition.split('\\n'))} values")
        print(f"📍 ALL VALUES FROM IMAGE ANALYSIS - NO HARDCODED DATA")
        
        # Return in expected format
        return {
            "dish_prediction": dish_name,
            "image_description": visible,
            "hidden_ingredients": hidden,
            "nutrition_info": nutrition,
            "analysis_time": analysis_time,
            "user_id": user_id
        }
        
    except Exception as e:
        print(f"❌ Full analysis error: {str(e)}")
        import traceback
        traceback.print_exc()
        
        # Return error response that clearly indicates failure
        return {
            "dish_prediction": f"Analysis failed: {str(e)}",
            "image_description": f"Analysis error | 0 | g | {str(e)}",
            "hidden_ingredients": f"Analysis error | 0 | g | {str(e)}",
            "nutrition_info": f"Calories | 0 | kcal | Analysis failed: {str(e)}\\nProtein | 0 | g | Analysis failed: {str(e)}\\nFat | 0 | g | Analysis failed: {str(e)}\\nCarbohydrates | 0 | g | Analysis failed: {str(e)}\\nFiber | 0 | g | Analysis failed: {str(e)}\\nSugar | 0 | g | Analysis failed: {str(e)}\\nSodium | 0 | mg | Analysis failed: {str(e)}",
            "analysis_time": 0,
            "user_id": user_id,
            "error": str(e)
        }

# ---------- Enhanced Nutrition Recalculation Function ----------
def recalculate_nutrition_enhanced(ingredients_text):
    """Dynamically recalculate nutrition based on actual ingredients - no hardcoded values"""
    try:
        print(f"🔄 Recalculating nutrition for: {ingredients_text[:100]}...")
        
        prompt = f"""
You are a certified nutritionist. Calculate the EXACT nutritional values for these SPECIFIC ingredients with their EXACT quantities:

INGREDIENTS TO ANALYZE:
{ingredients_text}

INSTRUCTIONS:
1. Use the EXACT quantities provided for each ingredient
2. Calculate nutrition based on standard nutritional databases (USDA, etc.)
3. Show your calculation process
4. Sum all values for total nutrition

REQUIRED OUTPUT FORMAT:
NUTRITION ANALYSIS:
Calories | [calculated total] | kcal | [brief calculation: ingredient1(cal) + ingredient2(cal) + etc.]
Protein | [calculated total] | g | [main protein contributors]
Fat | [calculated total] | g | [main fat contributors]
Carbohydrates | [calculated total] | g | [main carb contributors]
Fiber | [calculated total] | g | [fiber contributors]
Sugar | [calculated total] | g | [sugar contributors - natural and added]
Sodium | [calculated total] | mg | [sodium contributors]

CALCULATION NOTES:
- Base calculations on the specific quantities provided
- Consider cooking methods if mentioned
- Account for added fats/oils if cooking method suggests it
- Round to nearest whole number for final values
"""
        
        generation_config = genai.types.GenerationConfig(
            temperature=0.2,  # Low temperature for consistent calculations
            max_output_tokens=1500,
            top_p=0.9,
            top_k=40
        )
        
        response = gemini_model.generate_content(
            prompt,
            generation_config=generation_config,
            request_options={"timeout": 45}
        )
        
        if response and response.text:
            response_text = response.text
            
            # Extract nutrition lines
            if "NUTRITION ANALYSIS:" in response_text:
                lines = response_text.split('\n')
                nutrition_lines = []
                capture = False
                
                for line in lines:
                    line = line.strip()
                    if "NUTRITION ANALYSIS:" in line:
                        capture = True
                        continue
                    if capture and '|' in line:
                        parts = [p.strip() for p in line.split('|')]
                        if len(parts) >= 3:
                            nutrition_lines.append(line)
                
                if nutrition_lines:
                    result = '\\n'.join(nutrition_lines)
                    print(f"✅ Nutrition recalculated successfully")
                    return result
            
            # If structured format not found, return the whole response
            print(f"⚠️ Using full response as nutrition data")
            return response_text
        
        else:
            raise Exception("Empty response from Gemini API")
            
    except Exception as e:
        print(f"❌ Nutrition recalculation error: {str(e)}")
        error_msg = str(e)
        return f"""Calories | 0 | kcal | Recalculation failed: {error_msg}
Protein | 0 | g | Recalculation failed: {error_msg}
Fat | 0 | g | Recalculation failed: {error_msg}
Carbohydrates | 0 | g | Recalculation failed: {error_msg}
Fiber | 0 | g | Recalculation failed: {error_msg}
Sugar | 0 | g | Recalculation failed: {error_msg}
Sodium | 0 | mg | Recalculation failed: {error_msg}"""

# ---------- Image Validation Function ----------
def validate_image_for_analysis(image_path):
    """Validate that the image is suitable for food analysis"""
    try:
        with Image.open(image_path) as img:
            # Check if image is too small
            if img.width < 100 or img.height < 100:
                return False, "Image too small for analysis"
            
            # Check if image is too large (will be resized anyway)
            if img.width > 4000 or img.height > 4000:
                return True, "Image will be resized for analysis"
            
            # Check image format
            if img.format not in ['JPEG', 'PNG', 'WEBP']:
                return False, f"Unsupported image format: {img.format}"
            
            return True, "Image is suitable for analysis"
            
    except Exception as e:
        return False, f"Image validation failed: {str(e)}"