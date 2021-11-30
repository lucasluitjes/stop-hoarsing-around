# Installation

- Download and Install Anaconda (https://linuxize.com/post/how-to-install-anaconda-on-ubuntu-20-04/)
- To remove "(base)" from your terminal again:
`conda config --set auto_activate_base false`
- Create a new Anaconda Environment for the FastAI Book and set the python version for the environment to 3.7.
  At the time of writing, using a later python version will result in a ton of glibc version incompatibility
  errors when installing fastbook later:
`conda create --name fastbook python=3.7`
- Switch to the new environment:
`conda activate fastbook`
- Install pytorch, fastai and dependencies:
`conda install -c pytorch -c fastai fastai2`
- Install fastbook notebooks and dependencies:
`conda install -c fastai fastbook`
- Clone the FastAI book repo - Install git if needed:
`git clone https://github.com/fastai/fastbook`


- Install Ruby and required Ruby gems: 
  - Ruby: `sudo apt install ruby ruby-dev`
  - rb-inotify: `sudo apt install ruby-rb-inotify`
  - Gems: `sudo gem install fileutils open3 pry `

- Install Sound Exchange: `sudo apt install sox`
- Install ImageMagick:`sudo apt install imagemagick`


# Usage

- Activate fastbook environment: `conda activate fastbook`
- Run script: `ruby stop_hoarsing_around.rb`
