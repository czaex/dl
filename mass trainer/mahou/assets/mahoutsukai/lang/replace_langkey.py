import json
import io


replace = {
"mahoutsukai.book.william.name=Excerpt":"",
"mahoutsukai.book.william.desc= O glory to the ones who write the best!%%n For ye shall stand a head above the rest.%%n Thy Strengthened book upon a lectern place -%%n and judged it shall be on a case by case.%%n%%n For fame, how widespread is thy fiction's name?%%n Of word, both used and never before heard,%%n with frame, where punctuation is the game%%n and space, that sep'rate thoughts might not be blurred.":"",
"mahoutsukai.book.william_explanation.name=Notes":"",
"mahoutsukai.book.william_explanation.desc=It would seem that words themselves have power - crafting a work of writing, strengthening it, and placing it on a lectern will transform it into an artifact of sorts with properties dependent on the style of the text inside, and power dependent on the both the style of the text and the fame of the book, which can be increased through trading and being read by other players.":"",
"mahoutsukai.book.william2.name=Excerpt (cont.)":"",
"mahoutsukai.book.william2.desc= With mastery of form a writer earns%%n a plethora of mana in return%%n for close circuits thy craft empowers all -%%n with mage to one receptacle it falls.%%n%%n Of course with fiction comes theater true%%n and so when placed all shall take form anew":"",
"mahoutsukai.book.william2_explanation.name=Notes (cont.)":"",
"mahoutsukai.book.william2_explanation.desc=Placing the produced artifact in the world produces a sort of illusion magic that affects all nearby entities.%%n%%nNote that positive style will result in an instance of William, whilst negative style will result in an instance of R'lyeh - and each artifact has its own illusion magic and mana regeneration effects.":"",
"mahoutsukai.book.william3.name=Notes (cont.)":"",
"mahoutsukai.book.william3.desc=R'lyeh will drain mana from all nearby players, including the caster. William, on the other hand, will provide mana to nearby mana circuits (or the caster if held). The amount of mana is based on the style and fame of the text.%%n%%nNote that once the book is created, the style cannot be changed - a new book must be written to acquire higher style. Fiction creation costs (%%k * style) of the book that would be created.":"",
"mahoutsukai.book.william3_explanation.name=Notes (cont.)":"",
"mahoutsukai.book.william3_explanation.desc=Fame is increased when the book is traded to/from villagers or read by other players, and decreased when the book is burned. Style is based on the number of dictionary words, spaces, punctuation, character variety, lack of plagiarism from other players, etc.":""
           }

def langToJson(inf, outf):
    fin = open(inf, "rt", encoding='utf-8')
    data = fin.read()
    for r in replace:    
        data = data.replace(r, replace[r])
    fin.close()
    fin = open(outf, "wt", encoding="utf-8")
    fin.write(data)
    fin.close()

#langToJson("en_us.lang", "en_us.lang") 
langToJson("zh_cn.lang", "zh_cn.lang")
langToJson("hu_hu.lang", "hu_hu.lang")
langToJson("de_de.lang", "de_de.lang")
langToJson("la_va.lang", "la_va.lang")
langToJson("ru_ru.lang", "ru_ru.lang") 
langToJson("uk_ua.lang", "uk_ua.lang") 
langToJson("ja_jp.lang", "ja_jp.lang") 
langToJson("fr_fr.lang", "fr_fr.lang") 
langToJson("pt_br.lang", "pt_br.lang") 
langToJson("pt_pt.lang", "pt_pt.lang") 
langToJson("es_cl.lang", "es_cl.lang") 
langToJson("es_ar.lang", "es_ar.lang") 
langToJson("es_es.lang", "es_es.lang") 
langToJson("es_mx.lang", "es_mx.lang") 
langToJson("es_uy.lang", "es_uy.lang") 
langToJson("es_ve.lang", "es_ve.lang") 
langToJson("ko_kr.lang", "ko_kr.lang") 
langToJson("nl_nl.lang", "nl_nl.lang") 
langToJson("tr_tr.lang", "tr_tr.lang") 
