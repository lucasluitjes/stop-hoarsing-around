# run in terminal: sudo apt install python3-pip
# then run: pip3 install fastbook
# also run: pip3 install graphviz

import os
import random
import fastbook
fastbook.setup_book()

from fastai.vision.all import *

path = Path()

if len(sys.argv) >= 2:
  SAMPLE_SIZE = int(sys.argv[1])
else:
  print('Please input a sample size, testing with size 5')
  SAMPLE_SIZE = 5

learn_inf = load_learner('export.pkl')

tense_path = 'normalised-dataset/tense'
relaxed_path = 'normalised-dataset/relaxed'

tense_files = os.listdir(tense_path)
relaxed_files = os.listdir(relaxed_path)

tense_sample_files = random.sample(tense_files, SAMPLE_SIZE)
relaxed_sample_files = random.sample(relaxed_files, SAMPLE_SIZE)

tense_correct = 0
relaxed_correct = 0

for file in tense_sample_files:
  if learn_inf.predict(f"{tense_path}/{file}")[0] == 'tense':
    tense_correct += 1

for file in relaxed_sample_files:
  if learn_inf.predict(f"{relaxed_path}/{file}")[0] == 'relaxed':
    relaxed_correct += 1

print(f'tense correct: {tense_correct} out of {SAMPLE_SIZE}')
print(f'relaxed correct: {relaxed_correct} out of {SAMPLE_SIZE}')
