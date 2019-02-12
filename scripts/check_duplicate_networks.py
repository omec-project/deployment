import ConfigParser
import sys

S1MME=[]
S11=[]
S6A=[]
DB=[]
S5S8_SGWC =[]
S5S8_PGWC=[]
FPCNB=[]
FPCSB=[]
S1U=[]
S5S8_SGWU=[]
S5S8_PGWU=[]
SGI=[]

errors=[]
def parse_ini_file(file):
    config = ConfigParser.ConfigParser()
    config.optionxform = str
    config.read(file)
    return config

def check_network(config):
    for key, value in config.items("NETWORKS"):
      if value not in eval(key):
        eval(key).append(value)
      else:
          errors.append("Duplicate network found  "+key+" in "+file)


if __name__ == '__main__':
   if len(sys.argv)==1:
       print "Provide path of c3po_ngic_input.cfg of each frame separated by space "
       exit(0)
   else:
    #frames = ["frame1/c3po_ngic_input.cfg", "frame2/c3po_ngic_input.cfg","frame3/c3po_ngic_input.cfg"]
    iterfiles=iter(sys.argv)
    iterfiles.next()
    for file in iterfiles:
       print "Checking "+file
       check_network(parse_ini_file(file))
    if len(errors) > 0:
       print(errors)