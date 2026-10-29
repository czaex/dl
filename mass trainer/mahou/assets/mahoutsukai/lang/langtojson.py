import json
import io
def langToJson(inf, outf):
    file1 = io.open(inf, 'r',encoding='utf-8') 
    lines = file1.readlines()

    data = {}
    for line in lines:
        arr=[]
        arr+=[line[:line.find("=")]]
        arr+=[line[line.find("=")+1:]]
        if len(arr) == 2:
            if (arr[0].startswith("item.")):
                arr[0]=arr[0].replace("item.", "item.mahoutsukai.", 1)
            if (".book." not in arr[0] and ".config." not in arr[0]):
                arr[0]=arr[0].replace(".name","")
            #if (".config" in arr[0]):
                #arr[0] = arr[0].replace(".name.tooltip", ".comment");
            arr[0]=arr[0].replace("tile.","block.mahoutsukai.")
            if (arr[0].startswith("entity.mahoutsukai:")):
                arr[0]=arr[0].replace("entity.mahoutsukai:","entity.mahoutsukai.")
            arr[0]=arr[0].replace("spatial_disorientation_gauntlet", "spatial_disorientation_staff");            
            arr[0]=arr[0].replace("fluid.murky_water", "item.mahoutsukai.murky_bucket")
            arr[0]=arr[0].replace("itemGroup.MahouTsukai", "itemGroup.mahoutsukai")
            data[arr[0]] = arr[1][:-1]
    #print data

    with io.open(outf, 'w+', encoding='utf-8') as outfile:
        outfile.write(json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False))
        outfile.close()

langToJson("en_us.lang", "en_us.json") 
langToJson("zh_cn.lang", "zh_cn.json")
langToJson("hu_hu.lang", "hu_hu.json")
langToJson("de_de.lang", "de_de.json")
langToJson("la_va.lang", "la_va.json")
langToJson("ru_ru.lang", "ru_ru.json") 
langToJson("uk_ua.lang", "uk_ua.json") 
langToJson("ja_jp.lang", "ja_jp.json") 
langToJson("fr_fr.lang", "fr_fr.json") 
langToJson("pt_br.lang", "pt_br.json") 
langToJson("pt_pt.lang", "pt_pt.json") 
langToJson("es_cl.lang", "es_cl.json") 
langToJson("es_ar.lang", "es_ar.json") 
langToJson("es_es.lang", "es_es.json") 
langToJson("es_mx.lang", "es_mx.json") 
langToJson("es_uy.lang", "es_uy.json") 
langToJson("es_ve.lang", "es_ve.json") 
langToJson("ko_kr.lang", "ko_kr.json") 
