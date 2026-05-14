from flask import Flask

app = Flask(__name__)

# Example in-memory store (replace with DB integration)
items = []
@app.route("/")
def hello():
    return "Hello, World!"

@app.route("/api/items", methods=["POST"])
def create_item():
    data = request.get_json()
    name = data.get("name")
    description = data.get("description")

    # Example: save to list (replace with DB insert)
    item = {"name": name, "description": description}
    items.append(item)

    return jsonify({"message": "Item created", "item": item}), 201

if __name__ == "__main__":
	port = int(os.environ.get("PORT", 8080))
    app.run(host='0.0.0.0', port=port)

# Example in-memory store (replace with DB integration)
items = []

