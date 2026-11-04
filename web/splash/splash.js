function removeSplashFromWeb() {
  const elem = document.getElementById("splash");
  if (elem) {
    elem.remove();
  }
  document.body.style.backgroundColor = "#1A1A1A";
}
