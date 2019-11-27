To setup virtualenv
from the project base directory (where readme is)
python3 -m venv .aaenv
source .aaenv/bin/activate to activate the virtualenv
Install poetry
pip install poetry

The install all of the other dependencies
poetry install

To add a new dependency
poetry add mydependency


Create a .env in appy dir with the environment variables.

docker ps -a
docker run <imagename>
docker run -it --entrypoint /bin/bash <imageid>

docker build -t appy:latest .


docker run appy -p 8000:8000 -p 5432:5432

docker tag appy gcr.io/arevel-209217/appy:latest

docker tag appy us.gcr.io/arevel-209217/appy:latest
