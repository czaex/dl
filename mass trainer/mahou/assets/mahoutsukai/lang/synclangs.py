from shutil import copyfile

def synclang(inf,outf):
    file1 = open(inf, 'r') 
    lines = file1.readlines()

    data = {}
    for line in lines:
        arr=[]
        arr+=[line[:line.find("=")]]
        arr+=[line[line.find("=")+1:]]
        data[arr[0]] = arr[1]

    file1.close()
    file2 = open(outf, 'r')
    lines2 = file2.readlines();

    data2 = {}
    for line2 in lines2:
        arr=[]
        arr+=[line2[:line2.find("=")]]
        arr+=[line2[line2.find("=")+1:]]
        data2[arr[0]] = arr[1]
    file2.close()
    print outf + "================================"

    with open(outf, 'a') as outfile:
        for key in sorted(data.keys()):
            if (not key in data2) :
                print (key + "=" +data[key])
                outfile.write(key+"="+data[key])
                if not (data[key][-1] == '\n'):
                    outfile.write('\n')
    outfile.close()

def copylang(inf, outfs):
    for outf in outfs:
        copyfile(inf, outf)

    
synclang("en_us.lang", "zh_cn.lang")
synclang("en_us.lang", "hu_hu.lang")
synclang("en_us.lang", "de_de.lang")
synclang("en_us.lang", "la_va.lang")
synclang("en_us.lang", "ru_ru.lang")
synclang("en_us.lang", "uk_ua.lang")
synclang("en_us.lang", "ja_jp.lang")
synclang("en_us.lang", "fr_fr.lang")
synclang("en_us.lang", "pt_br.lang")
synclang("en_us.lang", "pt_pt.lang")
synclang("en_us.lang", "es_cl.lang")
synclang("en_us.lang", "ko_kr.lang")
copylang("es_cl.lang", ["es_ar.lang", "es_es.lang", "es_mx.lang", "es_uy.lang", "es_ve.lang"])

