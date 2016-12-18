#!/usr/bin/python

import cv2
import numpy as np
import os
import sys

if not len(sys.argv[1:]):
  print '\n\tUsage: match_pattern.py match_file\n'
  exit(1)

show = False
matchFile = sys.argv[1]
threshold = 0.8
patternDir = os.path.dirname(os.path.realpath(__file__))+'/patterns/'

patternDict = {}
for pfile in os.listdir(patternDir):
   f = open(patternDir+pfile,'rb')
   f2 = f.read()
   f.close()
   n = np.fromstring(f2,np.uint8)
   I = cv2.imdecode(n,cv2.CV_LOAD_IMAGE_COLOR)
   img_gray = cv2.cvtColor(I, cv2.COLOR_BGR2GRAY)
   patternDict.update({pfile:img_gray})

def check(img_gray,template):
  w, h = template.shape[::-1]

  res = cv2.matchTemplate(img_gray,template,cv2.TM_CCOEFF_NORMED)
  loc = np.where( res >= threshold)
  if not len(loc[0]) and not len(loc[1]):
     return False
  else:
    return True

def detectOS(b):
   match = False
   img2 = cv2.imread(matchFile)
   img = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)
   for m in patternDict.keys():
      match = check(img,patternDict[m])
      if match:
         windows = '_'.join(m.split('_')[:2])
         print windows
         break

   if not match:
      print 'other'

try:
 detectOS(matchFile)
except:
 print 'Exception'
