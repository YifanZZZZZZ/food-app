import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private let baseURL = "https://food-app-recipe.onrender.com"
    
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
    
    func uploadImage(imageData: Data, userId: String, completion: @escaping (Result<Meal, Error>) -> Void) {
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
                    
                    if data.isEmpty {
                        print("🛑 Empty response body received from server.")
                        completion(.failure(NSError(domain: "API", code: -10, userInfo: [NSLocalizedDescriptionKey: "Server returned no data."])))
                        return
                    }
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("🧾 Raw response (utf8):\n\(responseString)")
                        
                        if responseString.trimmingCharacters(in: .whitespacesAndNewlines).first != "{" {
                            print("⚠️ Warning: Response is not valid JSON. Possibly HTML or truncated.")
                        }
                    } else {
                        print("🧾 Raw response is not UTF-8 decodable.")
                        print("🧾 Raw base64:", data.base64EncodedString())
                    }
                }
                
                do {
                    let result = try JSONDecoder().decode(Meal.self, from: data)
                    completion(.success(result))
                } catch {
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
    
    func saveMeal(meal: MealUploadRequest, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/save-meal") else {
            print("❌ Invalid URL")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(meal)
            request.httpBody = jsonData
            print("📦 Sending meal JSON to \(url.absoluteString)")
        } catch {
            print("❌ JSON encoding failed:", error.localizedDescription)
            completion(false)
            return
        }

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network error:", error.localizedDescription)
                    completion(false)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    completion(false)
                    return
                }

                if httpResponse.statusCode == 200 {
                    print("✅ Meal saved successfully")
                    completion(true)
                } else {
                    if let data = data, let text = String(data: data, encoding: .utf8) {
                        print("❌ Server error: \(text)")
                    }
                    completion(false)
                }
            }
        }.resume()
    }

}
