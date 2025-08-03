import pandas as pd
from pymongo import MongoClient
from tqdm import tqdm

# MongoDB Atlas connection
MONGO_URI = "your_mongo_url"  # e.g. "mongodb+srv://<user>:<pass>@cluster.mongodb.net/"
DATABASE_NAME = "food-app-recipe"
COLLECTION_NAME = "recipes"

# Path to CSV
csv_file = "your_path_to_csv"

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

# Clean any previous dataset
collection.delete_many({})

# Insert with progress bar
inserted_ids = []
for record in tqdm(records, desc="Inserting recipes"):
    result = collection.insert_one(record)
    inserted_ids.append(result.inserted_id)

print(f"✅ Inserted {len(inserted_ids)} recipes.")