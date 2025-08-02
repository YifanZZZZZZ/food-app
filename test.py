import pandas as pd
from pymongo import MongoClient
from tqdm import tqdm

# MongoDB Atlas connection
MONGO_URI = "mongodb+srv://testuser:test123@cluster0.x4c2mxo.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"  # e.g. "mongodb+srv://<user>:<pass>@cluster.mongodb.net/"
DATABASE_NAME = "food-app-recipe"
COLLECTION_NAME = "recipes"

# Path to CSV
csv_file = "/Users/zhangyifan/food-app-recipe-v2/recipes.csv"

# Columns to keep
columns_to_keep = [
    "Name",
    "RecipeIngredientParts",
    "Calories",
    "FatContent",
    "SaturatedFatContent",
    "CholesterolContent",
    "SodiumContent",
    "CarbohydrateContent",
    "FiberContent",
    "SugarContent",
    "ProteinContent"
]

# Load and filter CSV
df = pd.read_csv(csv_file, usecols=columns_to_keep)

# Convert to dictionary records
records = df.to_dict(orient="records")
print("✅ Finished converting recipes.")

# Connect to MongoDB
client = MongoClient(MONGO_URI)
db = client[DATABASE_NAME]
collection = db[COLLECTION_NAME]
print("✅ Connected to MongoDB.")

# Optional: clear collection before insert (use with caution!)
# collection.delete_many({})

# Insert with progress bar
inserted_ids = []
for record in tqdm(records, desc="Inserting recipes"):
    result = collection.insert_one(record)
    inserted_ids.append(result.inserted_id)

print(f"✅ Inserted {len(inserted_ids)} recipes.")