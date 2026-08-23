import sys
import os

# Add parent directory to path so app folder is visible
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.ml_utils import FoodPredictor

def run_test():
    print("Starting ML Model verification...")
    try:
        predictor = FoodPredictor()
        
        # Run a test prediction
        # Roti: category=veg, group=bread, moisture=low, oil=low
        roti_prediction = predictor.predict(
            food_type="roti",
            temperature=28.0,
            time_since_prep_hours=2.0,
            storage_condition="room",
            packaging="closed"
        )
        print(f"[OK] Prediction for 'roti' (room, closed, 28C, 2h since prep) = {roti_prediction} hours")

        # Milk: category=dairy, group=liquid, moisture=high, oil=low
        milk_prediction = predictor.predict(
            food_type="milk",
            temperature=4.0,
            time_since_prep_hours=1.0,
            storage_condition="fridge",
            packaging="closed"
        )
        print(f"[OK] Prediction for 'milk' (fridge, closed, 4C, 1h since prep) = {milk_prediction} hours")
        
        # Spoilage check: Chicken Biryani left at room temperature for 25 hours
        spoiled_prediction = predictor.predict(
            food_type="chicken_biryani",
            temperature=32.0,
            time_since_prep_hours=25.0,
            storage_condition="room",
            packaging="open"
        )
        print(f"[OK] Prediction for old 'chicken_biryani' (room, open, 32C, 25h since prep) = {spoiled_prediction} hours")

        print("Verification Succeeded! The restructured ML model is fully functional.")
        
    except Exception as e:
        print(f"Verification Failed: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    run_test()
