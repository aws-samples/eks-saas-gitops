FROM python:3.9.17-slim
COPY producer.py /
COPY requirements.txt /
RUN pip install -r /requirements.txt
EXPOSE 80
ENTRYPOINT [ "python" ]
CMD [ "/producer.py" ]