FROM public.ecr.aws/lambda/python:3.11

# Install certbot and Route 53 plugin
RUN pip install certbot certbot-dns-route53 boto3

# Copy handler
COPY handler.py ${LAMBDA_TASK_ROOT}/

CMD ["handler.handler"]