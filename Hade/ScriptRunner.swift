//
//  ScriptRunner.swift
//  Hade
//
//  Yanıt döndükten sonra çalışan JavaScript'leri (post-response script) yürütür.
//  Script; `response` nesnesine erişebilir ve `setVar(...)` ile değişken atayabilir.
//

import Foundation
import JavaScriptCore

/// Bir script çalıştırmasının sonucu.
struct ScriptResult {
    var variables: [String: String] = [:]
    var logs: [String] = []
    var error: String?
}

enum ScriptRunner {
    /// Script'i çalıştırır ve set edilen değişkenleri, konsol loglarını ve hatayı döndürür.
    ///
    /// Script içinde kullanılabilir API:
    /// - `response.status` → HTTP durum kodu (sayı)
    /// - `response.body` → yanıt gövdesi (metin)
    /// - `response.headers` → header nesnesi
    /// - `response.json()` → gövdeyi JSON olarak ayrıştırır
    /// - `setVar("anahtar", değer)` → değişken atar (sonraki isteklerde {{anahtar}})
    /// - `console.log(...)` → konsola yazar
    static func run(script: String, response: ResponseResult) -> ScriptResult {
        guard let context = JSContext() else {
            return ScriptResult(error: "JavaScript bağlamı oluşturulamadı.")
        }

        var result = ScriptResult()

        context.exceptionHandler = { _, exception in
            result.error = exception?.toString() ?? "Bilinmeyen script hatası"
        }

        // console.log(...)
        let log: @convention(block) () -> Void = {
            let args = JSContext.currentArguments() as? [JSValue] ?? []
            result.logs.append(args.map { $0.toString() ?? "" }.joined(separator: " "))
        }
        let console = JSValue(newObjectIn: context)
        console?.setObject(log, forKeyedSubscript: "log" as NSString)
        context.setObject(console, forKeyedSubscript: "console" as NSString)

        // setVar("key", value)
        let setVar: @convention(block) (String, JSValue) -> Void = { key, value in
            let trimmed = key.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            if value.isNull || value.isUndefined {
                result.variables[trimmed] = ""
            } else {
                result.variables[trimmed] = value.toString() ?? ""
            }
        }
        context.setObject(setVar, forKeyedSubscript: "setVar" as NSString)

        // response nesnesi
        let responseObject = JSValue(newObjectIn: context)
        responseObject?.setObject(response.statusCode, forKeyedSubscript: "status" as NSString)
        responseObject?.setObject(response.bodyString, forKeyedSubscript: "body" as NSString)
        var headerDict: [String: String] = [:]
        for (key, value) in response.headers { headerDict[key] = value }
        responseObject?.setObject(headerDict, forKeyedSubscript: "headers" as NSString)
        context.setObject(responseObject, forKeyedSubscript: "response" as NSString)

        // response.json() yardımcı fonksiyonu
        context.evaluateScript("response.json = function() { return JSON.parse(response.body); };")

        // Kullanıcı script'ini çalıştır.
        context.evaluateScript(script)

        return result
    }
}
