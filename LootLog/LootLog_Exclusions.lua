-- LootLog_Exclusions.lua
-- Ключевые слова и паттерны для фильтрации сообщений о роллах/бросках и системных сообщениях
LootLog_Exclusions = {
    roll_keywords = {
        ["ruRU"] = {
            "разыгрывается", "результат", "выигрывает", 
            "не откажусь", "нужно", "мне это нужно", 
            "отказывается", "отказался", "распылить", 
            "вы выиграли"
        },
        ["enUS"] = {
            "roll", "result", "wins", "need", "greed", 
            "passed", "disenchant", "declined", 
            "chosen", "refused loot"
        }
    },
    roll_patterns = {
        "x%d+", -- количество (например, "x20")
        ":%s*%d+", -- число после двоеточия (например, "Result: 100")
        "[%s%p][%d]+[%s%p]", -- любое число с пробелами/знаками
        "выбирает ['\"]распылить['\"]", -- русский формат
        "chose to disenchant", -- английский
        "has chosen to disenchant", -- английский
        "has selected", -- английский
        "selected", -- английский
        "selected for loot" -- английский
    }
}