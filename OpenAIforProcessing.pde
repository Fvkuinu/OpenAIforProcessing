// This code includes portions licensed under the MIT License.
// Original code by Theo Kanning, available at https://github.com/TheoKanning/openai-java

ChatGPT gpt;
String gptApiKey = "<YOUR API KEY>";

void setup() {
  size(512, 512);


  //gptの初期化
  gpt = new ChatGPT(gptApiKey);
  
  //PImage[] images = new PImage[] {loadImage("cat.jpg"), loadImage("dog.jpg")};
  //println(gpt.visionAnalyzeMultiple("この画像の違いはなに、何人の人がうつってる？", images));
  
  //String[] images = new String[] {dataPath("cat.jpg"), dataPath("dog.jpg")};
  //println(gpt.visionAnalyzeMultiple("この画像の違いはなに、何人の人がうつってる？", images));
  
  //stream取得
  //gpt.sendMessageAsStream("秋刀魚とは");
  
  //会話する
  //gpt.addMessage("system","楽しいAIを演じてください");
  //String message = gpt.sendMessage("あなたは何者？"); //あなたのメッセージを送信して、返答を取得
  //println("ChatGPTの返答: "+message);

  //画像を一枚生成
  //PImage image = gpt.createImage("柴犬");
  //image(image, 0, 0);

  //画像を複数枚生成
  //PImage[] images = gpt.createImage("かわいい猫", 2);
  //for (int i=0; i<2; i++)  image(images[i], i*256, 0);

  //音声をテキストに文字起こし
  //String text = gpt.transcriptAudio(dataPath("コーヒーずんだもん.wav"));
  //println("文字起こし結果: "+text);

  //テキストから音声を生成して保存
  //gpt.asyncSaveAudioData("猫が鍵を落とし、鳥が拾い、友情が芽生えた。", "hoge.mp3");


  PFont font = createFont("Meiryo", 50);
  textFont(font);
  textSize(14);
}

void draw() {
  text(gpt.getStreamMessage(), 0, height/2);
}
