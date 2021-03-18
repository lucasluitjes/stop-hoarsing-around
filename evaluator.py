#!/usr/bin/env python3

import imghdr
import fastbook
import os
import sys

fastbook.setup_book()
from fastai.vision.all import *
learn_inf = load_learner('export.pkl')

for line in sys.stdin:
    if 'q\n' == line:
        break
    if 'exit\n' == line:
        break
    path = Path(line.rstrip())

    if path.exists() and imghdr.what(path) == 'png':
        png_path = path
        prediction = learn_inf.predict(png_path)
        print(f'{prediction[0]} - {png_path}\n')
    # testing:
    # normalised-dataset/tense/part1073.png
    # normalised-dataset/relaxed/part895.png
    #
    # ctrl+D to continue execution, exit() to terminate
    # import code; code.interact(local=dict(globals(), **locals()))
print("\n\nExcitedly exiting evaluator")
