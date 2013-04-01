class DroneController < UIViewController
  @emergency = 0
  @flying = 0
  @speedX = 0
  @speedY = 0
  @speedZ = 0
  @speedR = 0

  @controllingLeft = false
  @controllingRight = false

  class << self
    attr_accessor :emergency, :flying
  end

  @@sequence = 0

  def init
    super
    configureTimer
    connectSocket
    self
  end

  def viewDidLoad
    createUI
  end

  def configureTimer
    return NSTimer.scheduledTimerWithTimeInterval(0.030, target:self, selector:'sendCommand', userInfo:nil, repeats:true)
  end

  def connectSocket
    @socket = AsyncUdpSocket.alloc.initWithDelegate(self, delegateQueue:Dispatch::Queue.main)
  end

  def sendCommand
    ref = (self.class.emergency << 8) | (self.class.flying << 9)

    @@sequence += 1
    commands = "AT*REF=#{@@sequence},#{ref}\r"
    @@sequence += 1
    commands << "AT*PCMD=#{@@sequence},"+joystickMapToPCMD+"\r"

    data = commands.dataUsingEncoding(NSUTF8StringEncoding)
    @socket.sendData(data,toHost:"127.0.0.1",port:5556,withTimeout:0,tag:0)
    @socket.sendData(data,toHost:"192.168.1.1",port:5556,withTimeout:0,tag:0)
  end

  def createUI
    self.view.multipleTouchEnabled = true

    @uiBackground = addImage "background.png"
    @uiLeftJoystickHalo = addImage "joystick_halo.png"
    @uiRightJoystickHalo = addImage "joystick_halo.png"
    @uiLeftJoystickPointer = addImage "joystick_manuel.png"
    @uiRightJoystickPointer = addImage "joystick_manuel.png"
    @uiTakeOff = addImage "btn_take_off_normal.png", "handleTakeoff"
    @uiLanding = addImage "btn_landing.png", "handleLand"
    @uiEmergency = addImage "btn_emergency_normal.png", "handleEmergency"

    @uiLanding.setHidden true
    @uiLeftJoystickHalo.setHidden true
    @uiRightJoystickHalo.setHidden true
    @uiLeftJoystickPointer.setHidden true
    @uiRightJoystickPointer.setHidden true

    @uiTakeOff.setCenter [view.frame.size.height / 2, view.frame.size.width - @uiTakeOff.frame.size.height / 2]
    @uiLanding.setCenter [view.frame.size.height / 2, view.frame.size.width - @uiLanding.frame.size.height / 2]
    @uiEmergency.setCenter [view.frame.size.height / 2, @uiEmergency.frame.size.height / 2]
  end

private
  def addImage(imageName, tapHandler=nil)
    imageView = UIImageView.alloc.initWithImage UIImage.imageWithCGImage(UIImage.imageNamed(imageName).CGImage,scale:1.5,orientation:UIImageOrientationUp)
    self.view.addSubview imageView
    if tapHandler
      imageView.addGestureRecognizer UITapGestureRecognizer.alloc.initWithTarget(self, action:tapHandler)
      imageView.userInteractionEnabled = true
    end
    imageView.release
    imageView
  end

  def touchesBegan(touches, withEvent:event)
    touches.each do |touch|
      location = touch.locationInView(self.view)
      if location.x < view.frame.size.height / 2
        @controllingLeft = true
        @uiLeftJoystickHalo.setCenter location
        @uiLeftJoystickHalo.setHidden false
        @uiLeftJoystickPointer.setCenter location
        @uiLeftJoystickPointer.setHidden false
      else
        @controllingRight = true
        @uiRightJoystickHalo.setCenter location
        @uiRightJoystickHalo.setHidden false
        @uiRightJoystickPointer.setCenter location
        @uiRightJoystickPointer.setHidden false
      end
    end
  end

  def touchesMoved(touches, withEvent:event)
    touches.each do |touch|
      location = touch.locationInView(self.view)
      if location.x < view.frame.size.height / 2
        if @controllingLeft
          @uiLeftJoystickPointer.setCenter location
          joystickValue :left
        end
      else
        if @controllingRight
          @uiRightJoystickPointer.setCenter location
          joystickValue :right
        end
      end
    end
  end

  def touchesEnded(touches, withEvent:event)
    touches.each do |touch|
      location = touch.locationInView(self.view)
      if @controllingLeft && @controllingRight
        if location.x < view.frame.size.height / 2
          joystickHide :left
        else
          joystickHide :right
        end
      else
        joystickHide :both
      end
    end
  end

  def joystickHide side
    if side == :both
      joystickHide :left
      joystickHide :right
    elsif side == :left
      @controllingLeft = false
      @uiLeftJoystickHalo.setHidden true
      @uiLeftJoystickPointer.setHidden true
    else
      @controllingRight = false
      @uiRightJoystickHalo.setHidden true
      @uiRightJoystickPointer.setHidden true
    end
  end

  def joystickValue side
    if side == :left
      value = @controllingLeft ? [ @uiLeftJoystickPointer.center.x - @uiLeftJoystickHalo.center.x, @uiLeftJoystickHalo.center.y - @uiLeftJoystickPointer.center.y ] : [ 0, 0 ]
    else
      value = @controllingRight ? [ @uiRightJoystickPointer.center.x - @uiRightJoystickHalo.center.x, @uiRightJoystickHalo.center.y - @uiRightJoystickPointer.center.y ] : [ 0, 0 ]
    end

    ratio = 3
    value = [ value[0].to_f / (@uiLeftJoystickHalo.frame.size.width / ratio), value[1].to_f / (@uiLeftJoystickHalo.frame.size.height / ratio) ]
  end

  def joystickMapToPCMD
    leftJoystick = joystickValue :left
    rightJoystick = joystickValue :right

    result = [rightJoystick[0], -rightJoystick[1], leftJoystick[1], leftJoystick[0]]

    # limit values
    result.map! { |value| thresholdValue value }

    # convert float to int32
    result.map! { |value| floatTo32IntLE value }

    result.unshift(@controllingLeft || @controllingRight ? 1 : 0).join ","
  end

  def thresholdValue value
    [[value, -1].max, 1].min.to_f
  end

  def floatTo32IntLE floatNumber
    bytes = [floatNumber].pack('g').split("").map { |ds| ds[0].ord }
    unsigned = bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3] << 0
    signed = (unsigned & 0x80000000 == 0 ? unsigned : unsigned - 1 - 0xffffffff)
  end

  def handleTakeoff
    joystickHide :both
    @uiLanding.setHidden false
    @uiTakeOff.setHidden true
    self.class.emergency = 0
    self.class.flying = 1
  end

  def handleLand
    joystickHide :both
    @uiLanding.setHidden true
    @uiTakeOff.setHidden false
    self.class.flying = 0
  end

  def handleEmergency
    joystickHide :both
    self.class.emergency = 1
    handleLand
  end
end
