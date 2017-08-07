FROM golang:1.9-alpine

RUN apk add --no-cache \
  hugo \
  git

ENV \
  BLOG_ROOT="/home/blog" \
  BLOG_REPO="https://github.com/chrispotter/blog.git"
  HUGO_BASEURL="blog.chrispotter.io"

  # clone app
RUN git clone $BLOG_REPO $BLOG_ROOT

EXPOSE 80

WORKDIR /site $BLOG_ROOT

CMD git pull && \
  hugo server -p 80 -s blog.chrispotter
