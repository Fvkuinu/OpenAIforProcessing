import java.time.Duration;
import java.util.Base64;
import javax.imageio.ImageIO;
import java.io.ByteArrayInputStream;
import java.awt.image.MemoryImageSource;
import java.io.File;
import java.io.FileInputStream;
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
  final private String apiKey; //あなたのAPIkey
  private String version = "gpt-4o";//使用するGPTのバージョン 詳しく→ https://platform.openai.com/docs/models/gpt-4-and-gpt-4-turbo
  private int maxTokens = 100;  //最大のトークン数。文字数の制限みたいなもの。
  private double temperature = 1.0; //回答のランダム性 詳しく-> https://platform.openai.com/docs/api-reference/chat/create
  private String streamMessage = "";//ストリーミング取得しているテキスト
  private boolean isStreaming = false;

  //コンストラクタ（apiキー）
  public ChatGPT(String apiKey, String version, int maxTokens) {
    service = new OpenAiService(apiKey, Duration.ofSeconds(60));
    this.apiKey = apiKey;
    this.version = version; //enumのほうがよさげ
    this.maxTokens = maxTokens;
  }
  //コンストラクタ（apiキー、最大のトークン数）
  public ChatGPT(String apiKey, int maxTokens) {
    this(apiKey, "gpt-4o", maxTokens);
  }
  //コンストラクタ（apiキー、バージョン）
  public ChatGPT(String apiKey, String version) {
    this(apiKey, version, 100);
  }

  //コンストラクタ（apiキー）
  public ChatGPT(String apiKey) {
    this(apiKey, "gpt-4o", 100);
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

  //visionのメイン関数、複数枚、PImageで指定
  public String visionAnalyzeMultiple(String prompt, PImage[] images) {
    String responseMessage = null;
    
    String[] base64Images = new String[images.length];
    boolean allImagesEncoded = true;

    for (int i = 0; i < images.length; i++) {
      base64Images[i] = encodeImageToBase64(images[i], dataPath("temp" + i + ".jpg"));
      if (base64Images[i] == null) {
        allImagesEncoded = false;
        break;
      }
    }

    if (allImagesEncoded) {
      String payload = createPayload(prompt, base64Images);
      String apiUrl = "https://api.openai.com/v1/chat/completions";
      JSONObject response = makeApiRequest(apiUrl, payload);
      if (response != null) {
        responseMessage = extractContent(response);
      } else {
        println("Failed to get a response from the API");
      }
    } else {
      println("Failed to encode the images");
    }
    
    return responseMessage;
  }
  
  //エンコード用
  private String encodeImageToBase64(PImage img, String filename) {
    try {
      img.save(filename);
      File file = new File(filename);
      FileInputStream fis = new FileInputStream(file);
      byte[] byteArray = new byte[(int) file.length()];
      fis.read(byteArray);
      fis.close();
      file.delete(); // 一時ファイルを削除
      return Base64.getEncoder().encodeToString(byteArray);
    }
    catch (java.lang.Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  //visionのメイン関数、1枚、ファイルのパスを指定
  public String visionAnalyze(String prompt, String filename) {
    return visionAnalyzeMultiple(prompt, new String[] {filename});
  }

  //visionのメイン関数、複数枚、ファイルのパスを指定
  public String visionAnalyzeMultiple(String prompt, String[] filenames) {
    String responseMessage = null;
    
    String[] base64Images = new String[filenames.length];
    boolean allImagesEncoded = true;

    // 画像をBase64エンコード
    for (int i = 0; i < filenames.length; i++) {
      base64Images[i] = encodeImageToBase64(dataPath(filenames[i]));
      if (base64Images[i] == null) {
        allImagesEncoded = false;
        break;
      }
    }

    // 全ての画像がエンコードされた場合、APIリクエストを作成・送信
    if (allImagesEncoded) {
      String payload = createPayload(prompt, base64Images);
      String apiUrl = "https://api.openai.com/v1/chat/completions";
      JSONObject response = makeApiRequest(apiUrl, payload);
      if (response != null) {
        responseMessage = extractContent(response);
      } else {
        println("Failed to get a response from the API");
      }
    } else {
      println("Failed to encode the images");
    }
    
    return responseMessage;
  }

  // 画像をBase64にエンコードするメソッド
  private String encodeImageToBase64(String imagePath) {
    try {
      File file = new File(imagePath);
      FileInputStream fis = new FileInputStream(file);
      byte[] byteArray = new byte[(int) file.length()];
      fis.read(byteArray);
      fis.close();
      return Base64.getEncoder().encodeToString(byteArray);
    }
    catch (java.lang.Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  // APIリクエストのペイロードを作成するメソッド
  private String createPayload(String prompt, String[] base64Images) {
    JSONArray contentArray = new JSONArray();

    // テキストコンテンツを追加
    JSONObject textContent = new JSONObject();
    textContent.setString("type", "text");
    textContent.setString("text", prompt);
    contentArray.append(textContent);

    // 各画像URLコンテンツを追加
    for (String base64Image : base64Images) {
      JSONObject imageUrl = new JSONObject();
      imageUrl.setString("url", "data:image/jpeg;base64," + base64Image);

      JSONObject imageContent = new JSONObject();
      imageContent.setString("type", "image_url");
      imageContent.setJSONObject("image_url", imageUrl);

      contentArray.append(imageContent);
    }

    // メッセージオブジェクトを作成
    JSONObject message = new JSONObject();
    message.setString("role", "user");
    message.setJSONArray("content", contentArray);

    // メッセージ配列にメッセージを追加
    JSONArray messagesArray = new JSONArray();
    messagesArray.append(message);

    // ペイロードオブジェクトを作成
    JSONObject payload = new JSONObject();
    payload.setString("model", version);
    payload.setJSONArray("messages", messagesArray);
    payload.setInt("max_tokens", maxTokens);

    return payload.toString();
  }

  // APIリクエストを送信するメソッド
  private JSONObject makeApiRequest(String url, String payload) {
    try {
      URL apiURL = new URL(url);
      HttpURLConnection connection = (HttpURLConnection) apiURL.openConnection();
      connection.setRequestMethod("POST");
      connection.setRequestProperty("Content-Type", "application/json");
      connection.setRequestProperty("Authorization", "Bearer " + apiKey);
      connection.setDoOutput(true);

      // ペイロードを送信
      OutputStreamWriter writer = new OutputStreamWriter(connection.getOutputStream(), "UTF-8");
      writer.write(payload);
      writer.close();

      // レスポンスコードを確認
      int responseCode = connection.getResponseCode();
      if (responseCode == HttpURLConnection.HTTP_OK) {
        BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
        String inputLine;
        StringBuffer response = new StringBuffer();
        while ((inputLine = reader.readLine()) != null) {
          response.append(inputLine);
        }
        reader.close();
        return parseJSONObject(response.toString());
      } else {
        BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getErrorStream(), "UTF-8"));
        String inputLine;
        StringBuffer response = new StringBuffer();
        while ((inputLine = reader.readLine()) != null) {
          response.append(inputLine);
        }
        reader.close();
        println("HTTP Request failed with status code: " + responseCode);
        println("Response: " + response.toString());
        return null;
      }
    }
    catch (java.lang.Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  // レスポンスからコンテンツを抽出するメソッド
  private String extractContent(JSONObject jsonResponse) {
    try {
      JSONArray choices = jsonResponse.getJSONArray("choices");
      if (choices.size() > 0) {
        JSONObject choice = choices.getJSONObject(0);
        JSONObject message = choice.getJSONObject("message");
        return message.getString("content");
      } else {
        return "No content found in the response.";
      }
    }
    catch (java.lang.Exception e) {
      e.printStackTrace();
      return "Error extracting content.";
    }
  }

  //chatGPTの応答をストリーミング取得する。
  public void sendMessageAsStream(String prompt) {
    isStreaming = true;
    // メッセージリセット
    streamMessage = "";
    // APIへのリクエストを別スレッドで実行//メッセージリストに追加、メッセージをstring取得,utf-8に変換、全部送信
    addMessage("user", prompt);
    new Thread(new Runnable() {
      public void run() {
        chatWithGPT();
      }
    }
    ).start();
  }

  //ストリーム用の関数
  private void chatWithGPT() {

    int count = 0;
    try {
      // URLとHttpURLConnectionの設定
      URL url = new URL("https://api.openai.com/v1/chat/completions");
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
    isStreaming = false;
  }

  //ストリーミング取得しているテキストを取得
  String getStreamMessage() {
    return streamMessage;
  }
  boolean isStreaming(){
    return isStreaming;
  }
  
  public void saveMessages(String fileName) { //fileName を指定
    String savefile = "data/"+fileName;
    ArrayList<String> result = new ArrayList<String>();
    for (int i = 0; i < messages.size(); i++) {
      var mes = messages.get(i);
      if (mes.getRole().equals("system"))continue;
      result.add(mes.getRole()+","+mes.getContent());
    }
    String[] result2 = new String[result.size()];
    for (int i = 0; i < result.size(); i++) {
      result2[i] = result.get(i);
    }
    saveStrings(savefile, result2);
  }
  //テキストファイルの読み込みでメッセージを追加する
  public void loadMessages(String fileName) { //ファイルのパスを指定
    String[] lines = loadStrings(dataPath(fileName));
    for (String str : lines) {
      //if(str.equals("null")) continue;
      String[] mes = str.split(",", 2);
      addMessage(mes[0], mes[1]);
    }
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
 response = choice.getMessage().getContent();
 }
 println(response); //返答を出力
 */
