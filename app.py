from flask import Flask, request, jsonify
import tempfile
import os
from model_pipeline import full_image_analysis
from auth import auth_bp

app = Flask(__name__)
app.secret_key = 'your-secret'
app.register_blueprint(auth_bp)

@app.route("/analyze", methods=["POST"])
def analyze():
    if 'image' not in request.files or 'user_id' not in request.form:
        return jsonify({"error": "Missing image or user_id"}), 400
    image_file = request.files['image']
    user_id = request.form['user_id']

    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
        image_file.save(tmp.name)
        result = full_image_analysis(tmp.name, user_id)
    return jsonify(result)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    app.run(host="0.0.0.0", port=port)
