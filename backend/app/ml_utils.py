import os
import pickle
import pandas as pd
import numpy as np

# ---------------------------------------------
# 1. Food Metadata Dictionary
# ---------------------------------------------
FOOD_METADATA = {
    "plain_rice": {"category": "veg", "food_group": "rice", "moisture_level": "medium", "oil_content": "low"},
    "jeera_rice": {"category": "veg", "food_group": "rice", "moisture_level": "medium", "oil_content": "low"},
    "veg_pulao": {"category": "veg", "food_group": "rice", "moisture_level": "medium", "oil_content": "medium"},
    "chicken_biryani": {"category": "nonveg", "food_group": "rice", "moisture_level": "medium", "oil_content": "medium"},
    "roti": {"category": "veg", "food_group": "bread", "moisture_level": "low", "oil_content": "low"},
    "naan": {"category": "veg", "food_group": "bread", "moisture_level": "low", "oil_content": "medium"},
    "paratha": {"category": "veg", "food_group": "bread", "moisture_level": "low", "oil_content": "high"},
    "dal_tadka": {"category": "veg", "food_group": "curry", "moisture_level": "high", "oil_content": "low"},
    "paneer_butter_masala": {"category": "dairy", "food_group": "curry", "moisture_level": "high", "oil_content": "medium"},
    "chicken_curry": {"category": "nonveg", "food_group": "curry", "moisture_level": "high", "oil_content": "medium"},
    "fish_curry": {"category": "nonveg", "food_group": "curry", "moisture_level": "high", "oil_content": "low"},
    "milk": {"category": "dairy", "food_group": "liquid", "moisture_level": "high", "oil_content": "low"},
    "curd": {"category": "dairy", "food_group": "liquid", "moisture_level": "high", "oil_content": "low"},
    "samosa": {"category": "veg", "food_group": "fried", "moisture_level": "low", "oil_content": "high"},
    "pakora": {"category": "veg", "food_group": "fried", "moisture_level": "low", "oil_content": "high"},
    "idli": {"category": "veg", "food_group": "breakfast", "moisture_level": "medium", "oil_content": "low"},
    "dosa": {"category": "veg", "food_group": "breakfast", "moisture_level": "medium", "oil_content": "low"},
    "gulab_jamun": {"category": "dairy", "food_group": "sweet", "moisture_level": "high", "oil_content": "medium"},
    "halwa": {"category": "veg", "food_group": "sweet", "moisture_level": "medium", "oil_content": "high"}
}

class FoodPredictor:
    def __init__(self):
        current_dir = os.path.dirname(os.path.abspath(__file__))
        model_path = os.path.abspath(os.path.join(current_dir, "..", "model", "realistic_food_model.pkl"))
        columns_path = os.path.abspath(os.path.join(current_dir, "..", "model", "realistic_model_columns.pkl"))
        
        print(f"Loading ML model from: {model_path}")
        print(f"Loading columns from: {columns_path}")

        if not os.path.exists(model_path) or not os.path.exists(columns_path):
            raise FileNotFoundError("Model or column files not found. Ensure restructuring was completed.")

        with open(model_path, "rb") as f:
            self.model = pickle.load(f)
        
        with open(columns_path, "rb") as f:
            self.model_columns = list(pickle.load(f))
            
        print("Model and columns loaded successfully!")

    def predict(self, food_type: str, temperature: float, time_since_prep_hours: float, storage_condition: str, packaging: str) -> float:
        if food_type not in FOOD_METADATA:
            raise ValueError(f"Unknown food type: {food_type}")
        
        # 1. Fetch categorical metadata corresponding to food_type
        meta = FOOD_METADATA[food_type]
        category = meta["category"]
        food_group = meta["food_group"]
        moisture_level = meta["moisture_level"]
        oil_content = meta["oil_content"]
        
        # 2. Build dictionary of all values to be encoded
        # Initialize dictionary with zeros for all model columns
        input_data = {col: 0.0 for col in self.model_columns}
        
        # Set numerical features
        input_data["temperature"] = float(temperature)
        input_data["time_since_prep_hours"] = float(time_since_prep_hours)
        
        # Construct exact dummy column names matching pandas get_dummies
        dummy_keys = [
            f"food_type_{food_type}",
            f"category_{category}",
            f"food_group_{food_group}",
            f"moisture_level_{moisture_level}",
            f"oil_content_{oil_content}",
            f"storage_condition_{storage_condition}",
            f"packaging_{packaging}"
        ]
        
        # Set active dummies to 1.0
        for key in dummy_keys:
            if key in input_data:
                input_data[key] = 1.0
            else:
                # Debug print in case column wasn't in model training
                print(f"Warning: dummy column {key} not found in model columns!")
        
        # 3. Create DataFrame in correct column order
        df = pd.DataFrame([input_data], columns=self.model_columns)
        
        # 4. Predict
        prediction = self.model.predict(df)[0]
        return float(max(0.0, round(prediction, 2)))

    def get_metadata(self):
        return {
            "food_types": list(FOOD_METADATA.keys()),
            "food_details": FOOD_METADATA,
            "storage_conditions": ["room", "fridge"],
            "packaging_types": ["open", "closed"]
        }
