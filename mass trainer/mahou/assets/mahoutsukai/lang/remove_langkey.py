import json
import io


trunc = "item.william.name=William"

def remove_langkeys(inf, outf):
    with open(inf, "rt", encoding='utf-8') as fin:
        data = fin.readlines()
        new_ones = []
        for line in data:
            if trunc in line:
                break
            else:
                new_ones += [line]
    print(''.join(new_ones[-1]))


remove_langkeys("zh_cn.lang", "zh_cn.lang")
remove_langkeys("hu_hu.lang", "hu_hu.lang")
remove_langkeys("de_de.lang", "de_de.lang")
remove_langkeys("la_va.lang", "la_va.lang")
remove_langkeys("ru_ru.lang", "ru_ru.lang") 
remove_langkeys("uk_ua.lang", "uk_ua.lang") 
remove_langkeys("ja_jp.lang", "ja_jp.lang") 
remove_langkeys("fr_fr.lang", "fr_fr.lang") 
remove_langkeys("pt_br.lang", "pt_br.lang") 
remove_langkeys("pt_pt.lang", "pt_pt.lang") 
remove_langkeys("es_cl.lang", "es_cl.lang") 
remove_langkeys("es_ar.lang", "es_ar.lang") 
remove_langkeys("es_es.lang", "es_es.lang") 
remove_langkeys("es_mx.lang", "es_mx.lang") 
remove_langkeys("es_uy.lang", "es_uy.lang") 
remove_langkeys("es_ve.lang", "es_ve.lang") 
remove_langkeys("ko_kr.lang", "ko_kr.lang") 
remove_langkeys("nl_nl.lang", "nl_nl.lang") 
remove_langkeys("tr_tr.lang", "tr_tr.lang") 
