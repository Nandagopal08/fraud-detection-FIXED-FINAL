import pandas as pd
import os
import joblib
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler

print("🚀 Training model...")

# Load dataset
data = pd.read_csv("creditcard.csv")

print("Dataset loaded:", data.shape)

# Features & target
X = data.drop("Class", axis=1)
y = data["Class"]

# Split
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, stratify=y, random_state=42
)

print("Training data:", X_train.shape)

# Scale
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)

# ✅ Train model with optimized parameters
model = LogisticRegression(max_iter=5000, class_weight="balanced", solver="liblinear")
model.fit(X_train_scaled, y_train)

print("✅ Model trained")

# ✅ ADD DEBUG - Print model coefficients and intercept
print("🔍 Coef shape:", model.coef_.shape)
print("🔍 Intercept:", model.intercept_)
print("🔍 First 5 coefficients:", model.coef_[0][:5])

# Evaluate on test set
X_test_scaled = scaler.transform(X_test)
test_accuracy = model.score(X_test_scaled, y_test)
print(f"📊 Test accuracy: {test_accuracy:.4f}")

# Save model
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "models")

os.makedirs(MODEL_DIR, exist_ok=True)

model_path = os.path.join(MODEL_DIR, "fraud_model.pkl")
scaler_path = os.path.join(MODEL_DIR, "scaler.pkl")

joblib.dump(model, model_path)
joblib.dump(scaler, scaler_path)

print("✅ Model saved at:", model_path)
print("✅ Scaler saved at:", scaler_path)
print(f"✅ Model file size: {os.path.getsize(model_path)} bytes")
print(f"✅ Scaler file size: {os.path.getsize(scaler_path)} bytes")
