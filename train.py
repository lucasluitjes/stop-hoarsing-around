import fastbook
fastbook.setup_book()
from fastai.vision.all import *

if len(sys.argv) == 1:
    print('Please supply a foldername (containing spectrograms for training) as an argument')
    sys.exit(1)
else:
    foldername = sys.argv[1]
    path = Path(foldername)

    spectrograms = DataBlock(
        blocks=(ImageBlock, CategoryBlock),
        get_items=get_image_files,
        splitter=RandomSplitter(valid_pct=0.5, seed=43),
        get_y=parent_label)

    print(1)
    dls = spectrograms.dataloaders(path)

    print(2)
    learn = cnn_learner(dls, resnet18, metrics=error_rate,lr=0.005)
    learn.fine_tune(4)

    print(3)
    interp = ClassificationInterpretation.from_learner(learn)
    print(interp)

    learn.export()
    print(Path().ls(file_exts='.pkl'))
