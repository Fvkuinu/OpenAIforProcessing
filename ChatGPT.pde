/*
openai-java (version 0.16.0)
URL https://github.com/theokanning/openai-java
License The MIT License
https://opensource.org/licenses/mit-license.php
*/
import java.time.Duration;
import java.util.Base64;
import javax.imageio.ImageIO;
import java.io.ByteArrayInputStream;
import java.awt.image.MemoryImageSource;
import java.io.FileOutputStream;
import java.io.IOException;
import java.awt.image.BufferedImage;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.HttpURLConnection;
import java.net.URL;
import javax.net.ssl.HttpsURLConnection;
import java.lang.StringBuilder;

public class ChatGPT {

  final private OpenAiService service;  //サービスの設定内容（apiキー、サービスのタイムアウト（秒））
  final private ArrayList <ChatMessage> messages = new ArrayList <>();  //メッセージのリスト（履歴）
  final private String version = "gpt-4-1106-preview";//使用するGPTのバージョン 詳しく→ https://platform.openai.com/docs/models/gpt-4-and-gpt-4-turbo
  final private int maxTokens = 100;  //最大のトークン数。文字数の制限みたいなもの。
  final private double temperature = 1.0; //回答のランダム性 詳しく-> https://platform.openai.com/docs/api-reference/chat/create
  final private String apiKey; //あなたのAPIkey
  final private String apiEndpoint = "https://api.openai.com/v1/chat/completions";
  private String streamMessage = "";


  //コンストラクタ（apiキー）
  public ChatGPT(String apiKey) {
    this.apiKey = apiKey;
    service = new OpenAiService(apiKey, Duration.ofSeconds(60));
  }


  //メッセージを送信して、メッセージを取得　引数(プロンプト)
  public String sendMessage(String prompt) {
    String response = "";
    //メッセージをリストに追加
    final var message = new ChatMessage();
    message.setRole("user");
    message.setContent(prompt);
    messages.add(message);
    final var request = ChatCompletionRequest.builder()
      .model(version)
      .messages(messages)
      .maxTokens(maxTokens)
      .temperature(temperature)
      .build();
    //結果を取得
    final var completionResult = service.createChatCompletion(request);
    final var choiceList = completionResult.getChoices();
    for ( ChatCompletionChoice choice : choiceList) {
      response = choice.getMessage().getContent();  //帰ってきたメッセージのなかのコンテンツのみ取り出す
      addMessage("assistant", response);  //メッセージのリストに GPTからかえってきたメッセージを加える。
    }
    return response;
  }

  //自由にroleを指定してメッセージを追加
  //roleはsystem,user,assistant,functionの4種類（打ち間違いに注意）
  public void addMessage(String role, String prompt) {
    final var message = new ChatMessage();
    message.setRole(role);
    message.setContent(prompt);
    messages.add(message);
  }

  //メッセージのリスト（履歴）を取得 
  //ChatMessageクラスのリストになっていて
  //ChatMessage.getRole()でメッセージのロール
  //ChatMessage.getContent()でメッセージの内容 を取得可能
  public ArrayList<ChatMessage> getMessages() {
    return messages;
  }

  //音声をテキストに変換する(音声のファイルのパス入れる)
  //対応しているファイル形式(.mp3,.wavはいける）はここから確認 →https://platform.openai.com/docs/api-reference/audio
  public String transcriptAudio(String fileName) {
    var transcriptionRequest = CreateTranscriptionRequest.builder()
      .model("whisper-1")
      .build();
    return service.createTranscription(transcriptionRequest, dataPath(fileName))
      .getText();
  }


  //テキストから音声を生成してmp3で保存(fileNameは.mp3にすること)
  //これはopenai-javaの機能を使用していない。
  void saveAudioData(String text, String fileName) {
    HttpsURLConnection conn = null;
    OutputStream os = null;
    InputStream is = null;
    FileOutputStream fos = null;

    try {
      //リクエストを作成
      URL url = new URL("https://api.openai.com/v1/audio/speech");
      conn = (HttpsURLConnection) url.openConnection();
      conn.setRequestMethod("POST");
      conn.setRequestProperty("Authorization", "Bearer " + apiKey);
      conn.setRequestProperty("Content-Type", "application/json");
      conn.setDoOutput(true);

      //JSONを作成
      String jsonInputString = "{\"model\": \"tts-1\", \"input\": \""+text+"\", \"voice\": \"alloy\"}";

      //出力ストリームに出力
      os = conn.getOutputStream();
      byte[] input = jsonInputString.getBytes("utf-8");
      os.write(input, 0, input.length);

      //サーバーから応答を取得
      int responseCode = conn.getResponseCode();

      if (responseCode == HttpsURLConnection.HTTP_OK) { // success
        is = conn.getInputStream();
        fos = new FileOutputStream(dataPath(fileName));

        byte[] buffer = new byte[4096];
        int len;
        while ((len = is.read(buffer)) > 0) {
          fos.write(buffer, 0, len);
        }

      } else {
        println("POST request not worked.");
      }
    }
    catch(IOException e) {
      e.printStackTrace();
    }
    finally {
      //すべてのストリームと接続を必ず閉じる
      try {
        if (os != null) os.close();
        if (fos != null) fos.close();
        if (is != null) is.close();
      }
      catch(IOException e) {
        e.printStackTrace();
      }
      if (conn != null) conn.disconnect();
    }
  }

  //テキストから音声を生成（非同期）
  void asyncSaveAudioData(String text, String fileName) {
    new Thread(new Runnable() {
      public void run() {
        saveAudioData(text, fileName);
      }
    }
    ).start();
  }

  //音声を英語に翻訳してテキストに変換する 詳しく→https://platform.openai.com/docs/api-reference/audio/createTranscription
  public String translateAudio(String fileName) {
    var translateRequest = CreateTranslationRequest.builder()
      .model("whisper-1")
      .build();
    return service.createTranslation(translateRequest, dataPath(fileName))
      .getText();
  }

  //画像を1枚生成してPImageとして返す 引数:(プロンプト)
  public PImage createImage(String prompt) {
    // リクエストの作成
    CreateImageRequest req = CreateImageRequest.builder()
      .prompt(prompt) //生成する画像の説明
      .n(1) // 生成する画像の数。 1～10で選択
      .responseFormat("url") // "URL"とすればURLでの画像の指定
      .size("256x256") //生成する画像のサイズ、256x256, 512x512, 1024x1024から選択
      .build();

    // 画像生成の実施
    ImageResult imageResult = service.createImage(req);
    PImage image = loadImage(imageResult.getData().get(0).getUrl());
    return image;
  }

  //画像を複数枚生成してPImageのリストとして返す 引数:(プロンプト,枚数)
  public PImage[] createImage(String prompt, int n) {
    // リクエストの作成
    var req = CreateImageRequest.builder()
      .prompt(prompt) //生成する画像の説明
      .n(n) // 生成する画像の数。 1～10で選択
      .responseFormat("url") // "URL"とすればURLでの画像の指定
      .size("256x256") //生成する画像のサイズ、256x256, 512x512, 1024x1024から選択
      .build();

    var imageResult = service.createImage(req);
    //println(imageResult);
    var images = new PImage[n];
    for (int i=0; i<n; i++) {
      images[i] = loadImage(imageResult.getData().get(i).getUrl());
    }
    return images;
  }


  //入力画像から、それに似た別の画像を生成
  public PImage variateImage(String fileName) {
    var variateImgRequest = CreateImageVariationRequest.builder()
      .size("256x256")
      .responseFormat("url")
      .build();
    var imageResult = service.createImageVariation(variateImgRequest, dataPath(fileName));
    PImage image = loadImage(imageResult.getData().get(0).getUrl());
    return image;
  }

  //chatGPTの応答をストリーミング取得する。
  public void sendMessageAsStream(String prompt) {
    // メッセージリセット
    streamMessage = "";
    // APIへのリクエストを別スレッドで実行//メッセージリストに追加、メッセージをstring取得,utf-8に変換、全部送信
    addMessage("user", prompt);
    new Thread(new Runnable() {
      public void run() {
        chatWithOpenAI();
      }
    }
    ).start();
  }
  
  //ストリーム用の関数
  private void chatWithOpenAI() {

    int count = 0;
    try {
      // URLとHttpURLConnectionの設定
      URL url = new URL(apiEndpoint);
      HttpURLConnection connection = (HttpURLConnection) url.openConnection();
      connection.setRequestMethod("POST");
      connection.setRequestProperty("Content-Type", "application/json; ");
      connection.setRequestProperty("Authorization", "Bearer " + apiKey);
      connection.setDoOutput(true);


      //メッセージの部分を作成
      String messagesPart = "";
      for (int i = 0; i < messages.size(); i++) {
        var mes = messages.get(i);
        
        String  encodeText = mes.getContent();

        messagesPart += "{\"role\": \""+mes.getRole()+"\", \"content\": \""+mes.getContent()+"\"}";
        if (i != messages.size()-1)  messagesPart += ",";
      }
      // リクエストボディの作成
      String requestBody = "{"
        + "\"model\": \""+version+"\","
        + "\"max_tokens\": "+maxTokens+","
        + "\"temperature\": "+temperature+","
        + "\"messages\": ["
        + messagesPart
        + "],"
        + "\"stream\": true"
        + "}";

      // リクエストボディを送信
      OutputStreamWriter writer = new OutputStreamWriter(connection.getOutputStream(), "UTF-8");
      writer.write(requestBody);
      writer.close();

      // レスポンスコードの確認
      int responseCode = connection.getResponseCode();

      if (responseCode == HttpURLConnection.HTTP_OK) {
        // レスポンスを受け取る
        String dataLine;
        BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
        StringBuilder response = new StringBuilder();

        while ((dataLine = reader.readLine()) != null) {
          // レスポンスの各行を処理する
          // "data: "の部分を取り除く
          if (dataLine.startsWith("data: ")) {
            String jsonData = dataLine.substring("data: ".length());
            //[DONE]で取得終了
            if (dataLine.contains("[DONE]")) {
              break;
            }

            // JSONオブジェクトとしてパースする
            JSONObject json = parseJSONObject(jsonData);

            // "choices"配列から最初の要素を取得する
            JSONObject firstChoice = json.getJSONArray("choices").getJSONObject(0);

            // "delta"オブジェクトを取得する
            JSONObject delta = firstChoice.getJSONObject("delta");

            // "content"フィールドを取得する
            String content = delta.getString("content");

            //メッセージを追加していく
            if (content != null) {
              streamMessage += content;
            }
            
          }
        }
        //ここで読みとり終了
        reader.close();
      } else {
        println("Error: " + responseCode);
      }
    }
    catch (IOException e) {
      e.printStackTrace();
    }
  }
  
  //ストリーミング取得しているテキストを取得
  String getStreamMessage() {
    return streamMessage;
  }
  
}




/*
  リクエストの仕方（一つだけメッセージを送る場合）
 //リクエストの作成(echo,temperatureはなくても動く)
 CompletionRequest completionRequest = CompletionRequest.builder()
 .prompt(prompt) //プロンプト
 .model(model)  //モデル
 .echo(true) //わからん
 .maxTokens(maxTokens) //最大のトークン数
 .temperature(temperature) //よりクリエイティブなアプリケーションの場合は 0.9、答えが明確なアプリケーションの場合は 0
 .build();
 リクエストの送信
 CompletionChoice choice = service.createCompletion(completionRequest).getChoices().get(0);　//serviceはOpenAiServiceのインスタンス
 println(choice.getText()); //返答を出力
 
 
 リクエストの仕方（複数のメッセージを送る場合）
 メッセージのリストを作成
 ArrayList <ChatMessage> messages = new ArrayList <>(); // まず、メッセージのリストを作る
 var message = new ChatMessage(); //メッセージを一つ作成(型は ChatMessage)
 message.setRole("system");  //roleを指定。roleはsystem,user,assistant,functionの4種類。
 message.setContent(prompt); //プロンプトをセット
 messages.add(message);　//作ったメッセージを最初に作成したメッセージのリストに加える。
 リクエストの作成
 final var request = ChatCompletionRequest.builder()
 .model(version)
 .messages(messages) //ここにメッセージのリスト(型は ArrayList <ChatMessage>)を入れる
 .maxTokens(maxTokens)
 .temperature(temperature) //temperature入れたことないので動くか知らない
 .build();
 リクエストの送信
 var completionResult = service.createChatCompletion(request);　//serviceはOpenAiServiceのインスタンス
 var choiceList = completionResult.getChoices();　
 String response；　<-これにchatgptからの返答が入る。
 for ( ChatCompletionChoice choice : choiceList) {
 response = choice.getMessage().getContent(); //なんでfor文書くのかよくわかってない
 }
 println(response); //返答を出力
 */
