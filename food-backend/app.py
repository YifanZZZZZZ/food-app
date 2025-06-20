from flask import Flask, request, jsonify
import tempfile
from model_pipeline import full_image_analysis

app = Flask(__name__)

@app.route("/analyze", methods=["POST"])
def analyze():
    if 'image' not in request.files or 'user_id' not in request.form:
        return jsonify({"error": "Missing image or user_id"}), 400

    image_file = request.files['image']
    user_id = request.form['user_id']

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            image_file.save(tmp.name)
            result = full_image_analysis(tmp.name, user_id)

        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=True)
