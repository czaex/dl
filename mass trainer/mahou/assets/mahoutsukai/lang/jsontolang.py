import json
import io

def langToJson(inf, outf):
    file1 = open(inf, 'r') 
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
            if (".config" in arr[0]):
                arr[0] = arr[0].replace(".name.tooltip", ".comment");
            arr[0]=arr[0].replace("tile.","block.mahoutsukai.")
            if (arr[0].startswith("entity.mahoutsukai:")):
                arr[0]=arr[0].replace("entity.mahoutsukai:","entity.mahoutsukai.")
            arr[0]=arr[0].replace("spatial_disorientation_gauntlet", "spatial_disorientation_staff");            
            arr[0]=arr[0].replace("fluid.murky_water", "item.mahoutsukai.murky_bucket")
            arr[0]=arr[0].replace("itemGroup.MahouTsukai", "itemGroup.mahoutsukai")
            data[arr[0]] = arr[1][:-1]
    #print data

    with open(outf, 'w+') as outfile:
        outfile.write(json.dumps(data, indent=2, sort_keys=True))
        outfile.close()


def jsonToLang(inf, outf):
    file1 = open(inf, 'r', encoding="utf-8")
    
    data = json.load(file1)
    with io.open(outf, 'w+', encoding='utf-8') as outfile:
        for d in data:
            translation = data[d]
            key = d
            if (key.startswith('item.mahoutsukai.')):
                key = key.replace('item.mahoutsukai.', 'item.')
            if ('.book.' not in key
                and '.config.' not in key
                and 'advancements' not in key
                and 'effect.mahoutsukai' not in key
                and 'biome.mahoutsukai' not in key
                and 'dimension.mahoutsukai' not in key
                and 'enchantment.mahoutsukai' not in key
                and 'fluid.mahoutsukai' not in key
                and 'itemGroup' not in key
                and 'key.' not in key
                and 'mahouusage' not in key
                and not key.startswith('mahoutsukai.')) :
                key = key + '.name'
            if ('.config' in key):
                key = key.replace('.comment', '.name.tooltip')
            key = key.replace('block.mahoutsukai.', 'tile.')
            if (key.startswith('entity.mahoutsukai.')):
                key = key.replace('entity.mahoutsukai.', 'entity.mahoutsukai:')
            key = key.replace( "spatial_disorientation_staff","spatial_disorientation_gauntlet")
            key = key.replace( "item.mahoutsukai.murky_bucket", "fluid.murky_water")
            key = key.replace( "itemGroup.mahoutsukai","itemGroup.MahouTsukai")
            if (key != "" and translation != ""):
                outfile.write(key+'='+translation+'\n')
        outfile.close()
        
jsonToLang("ko_kr.json", "ko_kr.lang") 
jsonToLang("ru_ru.json", "ru_ru.lang") 
jsonToLang("uk_ua.json", "uk_ua.lang") 
jsonToLang("hu_hu.json", "hu_hu.lang") 
jsonToLang("zh_cn.json", "zh_cn.lang") 
