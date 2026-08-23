from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from app.ml_utils import FoodPredictor, FOOD_METADATA

app = FastAPI(
    title="FoodLink Prediction API",
    description="Machine Learning shelf-life prediction API for the FoodLink application.",
    version="1.0.0"
)

# Enable CORS for cross-origin requests (e.g., flutter web, local clients)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize predictor
try:
    predictor = FoodPredictor()
except Exception as e:
    print(f"Error loading FoodPredictor: {e}")
    predictor = None

# Pydantic Schemas
class PredictionRequest(BaseModel):
    food_type: str = Field(..., description="Type of food item", example="chicken_biryani")
    temperature: float = Field(..., ge=-5.0, le=60.0, description="Storage temperature in Celsius", example=25.5)
    time_since_prep_hours: float = Field(..., ge=0.0, le=72.0, description="Hours elapsed since food preparation", example=4.0)
    storage_condition: str = Field(..., description="Condition: fridge or room", example="room")
    packaging: str = Field(..., description="Packaging type: open or closed", example="closed")

class PredictionResponse(BaseModel):
    remaining_consumable_hours: float = Field(..., description="Predicted remaining consumable hours", example=14.5)
    food_type: str
    status: str = Field(..., description="Freshness status based on remaining hours: fresh, consume_soon, spoiled")

@app.get("/")
def read_root():
    return {"status": "online", "message": "Welcome to FoodLink Prediction API"}

@app.get("/metadata")
def get_metadata():
    if not predictor:
        raise HTTPException(status_code=500, detail="Model is not initialized.")
    return predictor.get_metadata()

@app.post("/predict", response_model=PredictionResponse)
def predict_shelf_life(request: PredictionRequest):
    if not predictor:
        raise HTTPException(status_code=500, detail="ML model is not loaded on server.")
    
    # Validation checks
    if request.food_type not in FOOD_METADATA:
        raise HTTPException(status_code=400, detail=f"Invalid food type. Choose from: {list(FOOD_METADATA.keys())}")
    
    if request.storage_condition not in ["room", "fridge"]:
        raise HTTPException(status_code=400, detail="storage_condition must be 'room' or 'fridge'")
    
    if request.packaging not in ["open", "closed"]:
        raise HTTPException(status_code=400, detail="packaging must be 'open' or 'closed'")
    
    try:
        remaining_hours = predictor.predict(
            food_type=request.food_type,
            temperature=request.temperature,
            time_since_prep_hours=request.time_since_prep_hours,
            storage_condition=request.storage_condition,
            packaging=request.packaging
        )
        
        # Categorize safety status
        if remaining_hours >= 12.0:
            status = "fresh"
        elif remaining_hours > 0.0:
            status = "consume_soon"
        else:
            status = "spoiled"
            
        return PredictionResponse(
            remaining_consumable_hours=remaining_hours,
            food_type=request.food_type,
            status=status
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")
