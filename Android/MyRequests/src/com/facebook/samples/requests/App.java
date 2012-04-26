package com.facebook.samples.requests;

import org.json.JSONException;
import org.json.JSONObject;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Toast;
import android.os.Handler;
import android.content.SharedPreferences;
import android.widget.Button;
import android.widget.TextView;

import com.facebook.android.*;
import com.facebook.android.R;
import com.facebook.android.Facebook.*;

public class App extends Activity {
	public static final String APP_ID = "264966473580049";
	final static int INVITE_TRIGGER_THRESHOLD = 3;
	
	Facebook facebook = new Facebook(APP_ID);
	private String requestId = null;
	private AsyncFacebookRunner mAsyncRunner;
	private Handler mHandler;
	private SharedPreferences mPrefs;
	private TextView mWelcomeLabel;
	private Button mLoginButton;
	private Button mSendRequestButton;
	
    /** Called when the activity is first created. */
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        
        // UI properties
        mWelcomeLabel = (TextView) findViewById(R.id.welcomeText);
        mLoginButton = (Button) findViewById(R.id.loginButton);
        mSendRequestButton = (Button) findViewById(R.id.sendRequestButton);
        
        // Facebook properties
        mAsyncRunner = new AsyncFacebookRunner(facebook);
        mHandler = new Handler();
        
        /*
         * Get existing saved session information
         */
        mPrefs = getPreferences(MODE_PRIVATE);
        String access_token = mPrefs.getString("access_token", null);
        long expires = mPrefs.getLong("access_expires", 0);
        if(access_token != null) {
            facebook.setAccessToken(access_token);
        }
        if(expires != 0) {
            facebook.setAccessExpires(expires);
        }
          
        // Parse any incoming notifications and save
        Uri intentUri = getIntent().getData();
        if (intentUri != null) {
        	String requestIdParam = intentUri.getQueryParameter("request_ids");
        	if (requestIdParam != null) {
        		String array[] = requestIdParam.split(",");
        		requestId = array[0];
        	}
        }
        
        if (facebook.isSessionValid()) {
        	// Set the logged in UI
        	mWelcomeLabel.setText(R.string.label_welcome);
        	mLoginButton.setText(R.string.button_logout);
        	// Get the request if the app is called as a result of an incoming
        	// notification.
        	if (requestId != null) {
        		mAsyncRunner.request(requestId, new RequestIdGetRequestListener());
        	}
        } else {
        	// Set the logged out UI
        	mWelcomeLabel.setText(R.string.label_login);
        	mLoginButton.setText(R.string.button_login);
        }
        
        mLoginButton.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
            	// Logging in
                if(!facebook.isSessionValid()) {
                	facebook.authorize(App.this, new DialogListener() {
                        @Override
                        public void onComplete(Bundle values) {
                        	// Set the logged in UI
                        	mWelcomeLabel.setText(R.string.label_welcome);
                        	mLoginButton.setText(R.string.button_logout);
                        	
                        	// Save session data
                        	SharedPreferences.Editor editor = mPrefs.edit();
                            editor.putString("access_token", facebook.getAccessToken());
                            editor.putLong("access_expires", facebook.getAccessExpires());
                            editor.commit();
                            
                        	// Process any available request
                        	if (requestId != null) {
                        		mAsyncRunner.request(requestId, new RequestIdGetRequestListener());
                        	}
                        }

                        @Override
                        public void onFacebookError(FacebookError error) {}

                        @Override
                        public void onError(DialogError e) {}

                        @Override
                        public void onCancel() {}
                    });
                } else {
                	// Logging out
                	mAsyncRunner.logout(App.this, new BaseRequestListener() {
                		@Override
                		public void onComplete(String response, Object state) {
                			/*
                             * callback should be run in the original thread, not the background
                             * thread
                             */
                            mHandler.post(new Runnable() {
                                @Override
                                public void run() {
                                	// Set the logged out UI
                                	mWelcomeLabel.setText(R.string.label_login);
                                	mLoginButton.setText(R.string.button_login);
                                	
                        			// Clear the token information
                        			SharedPreferences.Editor editor = mPrefs.edit();
                        			editor.putString("access_token", null);
                        			editor.putLong("access_expires", 0);
                        			editor.commit();
                                }
                            });
                		}
                	});
                }
            }
        });
        
        mSendRequestButton.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
            	 if(facebook.isSessionValid()) {
            		 // A request showing how to send extra data that could signify a gift
            		 Bundle params = new Bundle();
            		 params.putString("message", "Learn how to make your Android apps social");
            		 //params.putString("suggestions", "100001482211095,100003086810435,555279551,1053947411");
            		 params.putString("data", 
            		                  "{\"badge_of_awesomeness\":\"1\"," +
            		                  "\"social_karma\":\"5\"}");
            		 facebook.dialog(App.this, "apprequests", params, new DialogListener() {
            		    @Override
            		    public void onComplete(Bundle values) {
            		    	final String returnId = values.getString("request");
            		    	if (returnId != null) {
            		    		// Show the request Id if request sent successfully
            		    		Toast.makeText(getApplicationContext(), 
            		                			"Request sent: " +  returnId, 
            		                			Toast.LENGTH_SHORT).show();
            		    	}
            		    }

            		    @Override
            		    public void onFacebookError(FacebookError error) {}
            		     
            		    @Override
            		    public void onError(DialogError e) {}

            		    @Override
            		    public void onCancel() {
            		    	// Show a message if the user cancelled the request
            		    	Toast.makeText(getApplicationContext(), 
            		    			"Request cancelled", 
            		    			Toast.LENGTH_SHORT).show();
            		    }
            		 });
            	 } else {
            		 // If the session is not valid show a message
            		 Toast.makeText(getApplicationContext(), "You need to login to use send requests.", 
                     		Toast.LENGTH_LONG).show();
            	 }
            }
        });
    }
    
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        // Callback to handle the post-authorization flow.
        facebook.authorizeCallback(requestCode, resultCode, data);
    }
    
    @Override
    public void onResume() {
        super.onResume();
        
        // Extend the session information if it is needed
        if ((facebook != null) && facebook.isSessionValid()) {
            facebook.extendAccessTokenIfNeeded(this, null);
        }
        
        // Check and increment app use counter for triggering friend invites
        boolean appUseCheckEnabled = mPrefs.getBoolean("app_usage_check_enable", true);
        int appUseCount = mPrefs.getInt("app_usage_count", 0);
        appUseCount++;       
        // Trigger invite if over threshold
        if ((facebook != null) && facebook.isSessionValid() &&
        		appUseCheckEnabled && (appUseCount >= INVITE_TRIGGER_THRESHOLD)) {
        	appUseCount = 0;
        	AlertDialog.Builder builder = new AlertDialog.Builder(this);
        	builder.setMessage("If you enjoy using this app, would you mind " +
        			"taking a moment to invite a few friends that you think " +
        			"will also like it?")
        	       .setCancelable(false)
        	       .setPositiveButton("Tell Friends", new DialogInterface.OnClickListener() {
        	           public void onClick(DialogInterface dialog, int id) {
        	        	   // Show the friends invite
        	        	   Bundle params = new Bundle();
                  		   params.putString("message", "Check out this awesome app");
                  		   facebook.dialog(App.this, "apprequests", params, new DialogListener() {
                  		    @Override
                  		    public void onComplete(Bundle values) {
                  		    	final String returnId = values.getString("request");
                  		    	if (returnId != null) {
                  		    		Toast.makeText(getApplicationContext(), 
                  		                			"Request sent: " +  returnId, 
                  		                			Toast.LENGTH_SHORT).show();
                  		    	}
                  		    }

                  		    @Override
                  		    public void onFacebookError(FacebookError error) {}
                  		     
                  		    @Override
                  		    public void onError(DialogError e) {}

                  		    @Override
                  		    public void onCancel() {
                  		    	Toast.makeText(getApplicationContext(), 
                  		    			"Request cancelled", 
                  		    			Toast.LENGTH_SHORT).show();
                  		    }
                  		 });
        	           }
        	       })
        	       .setNegativeButton("No Thanks", new DialogInterface.OnClickListener() {
        	           public void onClick(DialogInterface dialog, int id) {
        	        	   // Set the flag so the user is not prompted to invite friends again
        	        	   mPrefs.edit().putBoolean("app_usage_check_enable", false).commit();
        	               dialog.cancel();
        	           }
        	       })
        	       .setNeutralButton("Remind Me", new DialogInterface.OnClickListener() {
        	           public void onClick(DialogInterface dialog, int id) {
        	                dialog.cancel();
        	           }
        	       });
        	AlertDialog alert = builder.create();
        	alert.show();
        }
        // Save app use counter
        mPrefs.edit().putInt("app_usage_count", appUseCount).commit();
    }
    
    /*
     * Callback on get of request information
     */
    public class RequestIdGetRequestListener extends BaseRequestListener {
    	
    	@Override
    	public void onComplete(final String response, Object state) {
    		try {
    			// Get the return data and check if this is a gift type
    			// of request (where there is extra data), or if this is
    			// a friend invite request.
    			final String title;
    			final String message;
    			JSONObject jsonObject = new JSONObject(response);
    			String from = jsonObject.getJSONObject("from").getString("name");
    			if (jsonObject.getString("data") != null) {
    				String data = jsonObject.getString("data");
    				JSONObject dataObject = new JSONObject(data);
    				String badge = dataObject.getString("badge_of_awesomeness");
    				String karma = dataObject.getString("social_karma");
    				title = from+" sent you a gift";
    				message = "Badge: "+badge+" Karma: "+karma;
    			} else {
    				title = from+" sent you a request";
    				message = jsonObject.getString("message");
    			}
    			mHandler.post(new Runnable() {
                    @Override
                    public void run() {
                    	// Show the relevant request information
                        Toast.makeText(getApplicationContext(), title + "\n\n" + message, 
                        		Toast.LENGTH_LONG).show();
                        // Delete the request
                        Bundle params = new Bundle();
                        params.putString("method", "delete");
                        mAsyncRunner.request(requestId, params, new RequestIdDeleteRequestListener());
                    }
                });
    		} catch (JSONException e) {
    			// Could be due to a few things including reading a notification
    			// that has been deleted but still shows up in the Facebook app.
                e.printStackTrace();
            }
		};
    }
    
    /*
     * Callback on request deletion
     */
    public class RequestIdDeleteRequestListener extends BaseRequestListener {  	
    	@Override
    	public void onComplete(final String response, Object state) {
    			mHandler.post(new Runnable() {
                    @Override
                    public void run() {
                    	// Display a message that the request has been deleted
                        Toast.makeText(getApplicationContext(), "Request deleted", 
                        		Toast.LENGTH_SHORT).show();
                    }
                });
		};
    }
}