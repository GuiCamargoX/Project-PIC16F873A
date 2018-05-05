import { FingerprintAIO } from '@ionic-native/fingerprint-aio';
import { BluetoothSerial } from '@ionic-native/bluetooth-serial';
import { Component } from '@angular/core';
import { NavController } from 'ionic-angular';
import { AlertController } from 'ionic-angular';

@Component({
  selector: 'page-home',
  templateUrl: 'home.html'
})
export class HomePage {
  private _macAddress : string;

  constructor(public navCtrl: NavController, private _faio : FingerprintAIO, private _alertCtrl: AlertController,
    private _bluetoothSerial: BluetoothSerial ) { 
      
      this._macAddress = "00:21:13:00:4F:0D"; 
      this._bluetoothSerial.enable();
  
    }


  showAlert(msg: string) {
    let alert = this._alertCtrl.create({
      title: 'Error',
      subTitle: msg,
      buttons: ['OK']
    });
    alert.present();
  }

  showFingerprintDialog(){
    
    this._faio.show({
      clientId: 'Fingerprint-Demo',
      clientSecret: 'password', //Only necessary for Android
      disableBackup:true,  //Only for Android(optional)
  })
  .then((result: any) => {
    this.sendByte(0x01);
    
    let alert = this._alertCtrl.create({
      title: 'Aviso',
      subTitle: 'Você tem aproximadamente 10 segundos para abrir a porta!',
      buttons: ['OK']
    });
    alert.present();
  
  } )
  .catch((error: any) => this.showAlert(error)  )
  
  }

  public connectModule(){

    this._bluetoothSerial.connect(this._macAddress).subscribe( (data) => this.showAlert(data), (error) => this.showAlert(error) );
    
  }

  public sendByte( option: number ) {
    var byte = new Uint8Array(1); //Cria um vetor que contem apenas um elemento
    byte[0] = option;
    this._bluetoothSerial.write(byte).then((sucess)=>{ //envia dado
    },
    (err)=>{
    });
  }

  public setParty(){
    this.sendByte(0x02);

    let alert = this._alertCtrl.create({
      title: 'Disconnect',
      message: 'Do you want to Stop?',
      buttons: [
        {
          text: 'Yes',
          role: 'cancel',
          handler: () => {
            this.sendByte(0x03)
          }
        }
      ]
    });
    alert.present();

  }

}
