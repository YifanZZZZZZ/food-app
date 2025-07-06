import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private let baseURL = "https://food-app-swift.onrender.com"
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        
        // Disable QUIC to avoid protocol issues
        config.httpMaximumConnectionsPerHost = 2
        
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    func checkHealth(completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(false, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Health check error: \(error)")
                    completion(false, "Network error")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Health check status: \(httpResponse.statusCode)")
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    completion(status == "healthy", status)
                } else {
                    completion(false, "Invalid response")
                }
            }
        }.resume()
    }
    
    func uploadImage(imageData: Data, userId: String, completion: @escaping (Result<GeminiResult, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/analyze") else {
            completion(.failure(NSError(domain: "NetworkManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("📤 Uploading image to: \(url)")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Upload error: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "NetworkManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Response status: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode != 200 {
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(responseString)")
                        }
                    }
                }
                
                do {
                    let result = try JSONDecoder().decode(GeminiResult.self, from: data)
                    completion(.success(result))
                } catch {
                    // Try to decode error response
                    if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                       let errorMsg = errorDict["error"] {
                        completion(.failure(NSError(domain: "API", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                    } else {
                        print("❌ Decode error: \(error)")
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    func recalculateNutrition(ingredients: String, userId: String, completion: @escaping (Result<NutritionRecalculationResult, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/recalculate-nutrition") else {
            completion(.failure(NSError(domain: "NetworkManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let payload: [String: Any] = [
            "ingredients": ingredients,
            "user_id": userId
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(NSError(domain: "NetworkManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode data"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "NetworkManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(NutritionRecalculationResult.self, from: data)
                    completion(.success(result))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func updateMeal(mealId: String, dishName: String, ingredients: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/update-meal") else {
            completion(false)
            return
        }
        
        let payload: [String: Any] = [
            "meal_id": mealId,
            "dish_prediction": dishName,
            "image_description": ingredients
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        session.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    func deleteMeal(mealId: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/delete-meal") else {
            completion(false)
            return
        }
        
        let payload = ["meal_id": mealId]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        session.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}
